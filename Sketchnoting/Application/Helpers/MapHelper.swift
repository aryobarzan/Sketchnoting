//
//  MapHelper.swift
//  Sketchnoting
//
//  Created by Aryobarzan on 04/07/2019.
//  Copyright © 2019 Aryobarzan. All rights reserved.
//

import UIKit
import Alamofire
import NaturalLanguage

class MapHelper {
    private static let mapQuestAPIKey = "bAELaFV3A8vNwICyhbziI7tNeSfYdUvr"
    private static func fetchMap(location: String, document: Document) {
        let parameters: Parameters = ["q": location, "maxRows": 1, "username": "aryo"]
        let headers: HTTPHeaders = [
                "Accept": "application/json"
        ]
        AF.request("http://api.geonames.org/searchJSON", parameters: parameters, headers: headers).responseJSON { response in
            let responseResult = response.result
            var json = [String : Any]()
            switch responseResult {
            case .success(let res):
                json = res as! [String: Any]
            case .failure( _):
                return
            }
            log.info("GeoNames Coordinates: API call successful.")
                
            let result = json
            let resources = result["geonames"] as? [[String: Any]]
            if resources != nil {
                for res in resources! {
                    let latitude = res["lat"] as! String
                    let longitude = res["lng"] as! String
                    self.fetchMapImage(latitude: latitude, longitude: longitude, document: document)
                }
            }
            else {
                log.error("GeoNames Coordinates: API call failed.")
            }
        }
    }
    static func fetchMapImage(latitude: String, longitude: String, document: Document) {
        DispatchQueue.global(qos: .utility).async {
            if let url = URL(string: "https://www.mapquestapi.com/staticmap/v5/map?key=" + mapQuestAPIKey + "&center=" + latitude + "," + longitude + "&size=800,600") {
                document.downloadImage(url: url, type: .Map)
                log.info("Map image could be found for document \(document.title).")
            }
            else {
                log.error("No map image could be found for document \(document.title).")
            }
        }
    }
    
    private static func isPlace(document: Document) -> Bool {
        for t in SemanticSearch.tag(text: document.title, scheme: .nameType) {
            if t.1 == "PlaceName" {
                return true
            }
        }
        if let tagmeDocument = document as? TAGMEDocument {
            if let categories = tagmeDocument.categories {
                for category in categories {
                    var trimmed = category
                    if category.contains(":") {
                        if let range = category.range(of: ":") {
                            trimmed = String(category[range.upperBound...])
                        }
                    }
                    for t in SemanticSearch.tag(text: trimmed, scheme: .nameType) {
                        if t.1 == "PlaceName" {
                            return true
                        }
                    }
                    let tokens = SemanticSearch.tokenize(text: trimmed, unit: .word)
                    var minimumSimilarity = 999.0
                    for token in tokens {
                        let lemma = SemanticSearch.lemmatize(text: token)
                        let similarity = SemanticSearch.wordDistance(between: lemma, and: "place")
                        if similarity < minimumSimilarity {
                            minimumSimilarity = similarity
                        }
                    }
                    if minimumSimilarity <= 1.0 {
                        return true
                    }
                }
            }
        }
        return false
        // MARK: Old method
        //let placeTerms = ["place", "city", "populated", "country", "capital", "location", "state", "village"]
        //for term in placeTerms {
        //    if document.description?.lowercased().contains(term) ?? false {
        //        return true
        //    }
        //}
        //return false
    }
    
    static func downloadMap(document: Document) {
        if isPlace(document: document) {
            fetchMap(location: document.title, document: document)
        }
        else {
            KnowledgeGraphHelper.isPlace(name: document.title, completionHandler: { isPlace in
                if isPlace {
                    fetchMap(location: document.title, document: document)
                }
            })
        }
    }
}

//
//  DBpediaHelper.swift
//  Sketchnoting
//
//  Created by Aryobarzan on 08/07/2019.
//  Copyright © 2019 Aryobarzan. All rights reserved.
//

import UIKit
import Alamofire
import SwiftyJSON

class SpotlightHelper {
    func fetch(text: String, note: Note) {
        let chunks = text.split(by: 6000)
        
        for chunk in chunks {
            let (confidence, _) = calculate_confidence_support(l: Double(chunk.count))
            let parameters: Parameters = ["text": chunk, "confidence": confidence]
            let headers: HTTPHeaders = [
                "Accept": "application/json"
            ]
            AF.request("http://api.dbpedia-spotlight.org/en/annotate", parameters: parameters, headers: headers).responseJSON { response in
                let responseResult = response.result
                var json = JSON()
                switch responseResult {
                case .success(let res):
                    json = JSON(res)
                case .failure(let error):
                    print(error.localizedDescription)
                }
                print("JSON: \(json)")
                var results = [String: String]()
                
                if let resources = json["Resources"].array {
                    for res in resources {
                        if let concept = res["@surfaceForm"].string, let conceptURI = res["@URI"].string, let secondRankPercentage = res["@percentageOfSecondRank"].string {
                            if !concept.isEmpty && !conceptURI.isEmpty && results[concept] == nil {
                                results[concept] = conceptURI
                                if let resourceName = self.extractValueWithRegex(pageSource: conceptURI, pattern: "http://dbpedia.org/resource/(.*)"), let _ = URL(string: "http://dbpedia.org/data/" + resourceName + ".json") {
                                    print(resourceName)
                                    self.fetchJSONOfResource(concept: concept, conceptURI: conceptURI, secondRankPercentage: Double(secondRankPercentage) ?? 0, resourceJSONURL: "http://dbpedia.org/data/" + resourceName + ".json", note: note)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    private func fetchJSONOfResource(concept: String, conceptURI: String, secondRankPercentage: Double, resourceJSONURL: String, note: Note) {
        let headers: HTTPHeaders = [
            "Accept": "application/json"
        ]
        AF.request(resourceJSONURL, headers: headers).responseJSON { response in
            let responseResult = response.result
            var json = JSON()
            switch responseResult {
            case .success(let res):
                json = JSON(res)
            case .failure(let error):
                print(error.localizedDescription)
            }
            if let content = json[conceptURI].dictionary {
                var types = [String]()
                var label : String?
                var abstract : String?
                var thumbnail : UIImage?
                var wikiPageID : Double?
                var latitude : Double?
                var longitude : Double?
                if let typeArray = content["http://www.w3.org/1999/02/22-rdf-syntax-ns#type"]?.array {
                    for type in typeArray {
                        if let value = type["value"].string {
                            if value.contains("http://dbpedia.org/ontology/") {
                                if let typeName = self.extractValueWithRegex(pageSource: value, pattern: "http://dbpedia.org/ontology/(.*)") {
                                    types.append(typeName)
                                }
                            }
                        }
                    }
                }
                if let labelArray = content["http://www.w3.org/2000/01/rdf-schema#label"]?.array {
                    for l in labelArray {
                        if let value = l["value"].string, let lang = l["lang"].string {
                            if lang.lowercased() == "en" {
                                label = value
                            }
                        }
                    }
                }
                if let abstractArray = content["http://dbpedia.org/ontology/abstract"]?.array {
                    for abs in abstractArray {
                        if let value = abs["value"].string, let lang = abs["lang"].string {
                            if lang.lowercased() == "en" {
                                abstract = value
                            }
                        }
                    }
                }
                
                if let thumbnailArray = content["http://dbpedia.org/ontology/thumbnail"]?.array {
                    if let value = thumbnailArray[0]["value"].string {
                        let url = URL(string: value)
                        if let url = url {
                            do {
                                let data = try Data(contentsOf: url)
                                let image = UIImage(data: data)
                                thumbnail = image
                            } catch {
                                print(error.localizedDescription)
                            }
                        }
                    }
                }
                
                if let wikiPageIDArray = content["http://dbpedia.org/ontology/wikiPageID"]?.array {
                    if let value = wikiPageIDArray[0]["value"].double {
                        wikiPageID = value
                    }
                }
                if let latitudeArray = content["http://dbpedia.org/property/latd"]?.array {
                    if let value = latitudeArray[0]["value"].double {
                        latitude = value
                    }
                }
                if let longitudeArray = content["http://dbpedia.org/property/longd"]?.array {
                    if let value = longitudeArray[0]["value"].double {
                        longitude = value
                    }
                }
                
                if let document = SpotlightDocument(title: concept, description: abstract, URL: conceptURI, type: .Spotlight, rank: secondRankPercentage, label: label, types: types, wikiPageID: wikiPageID, latitude: latitude, longitude: longitude, mapImage: nil) {
                    if let latitude = latitude, let longitude = longitude {
                        MapHelper.fetchMapImage(latitude: String(latitude), longitude: String(longitude), document: document, note: note)
                    }
                    else {
                        for type in types {
                            if type.lowercased().contains("place") || type.lowercased().contains("location") || type.lowercased().contains("event") {
                                MapHelper.fetchMap(location: concept, document: document, note: note)
                                break
                            }
                        }
                    }                        
                    note.addDocument(document: document)
                }
            }
        }
    }
    
    private func get_slope_intercept(x1: Double, x2: Double, y1: Double, y2: Double) -> (Double, Double) {
        let slope = (y2 - y1) / (x2 - x1)
        let intercept = y1 - slope * x1
        return (slope, intercept)
    }
    
    
    private func interpolate(xRange: [Double], yRange: [Double], x: Double) -> Double {
        let (slope, intercept) = get_slope_intercept(x1: xRange[0], x2: xRange[1], y1: yRange[0], y2: yRange[1])
        let y = slope * x + intercept
        return y
    }
    
    private func calculate_confidence_support(l: Double) -> (Double, Double) {
        var confidence = 0.5
        var support = 20.0
        if (0 ... 500).contains(l) {
            confidence = interpolate(xRange: [0, 500], yRange: [0.1, 0.25], x: l)
            support = interpolate(xRange: [0, 500], yRange: [5, 10], x: l)
        }
        else if (500 ... 1000).contains(l) {
            confidence = interpolate(xRange: [500, 1000], yRange: [0.2, 0.35], x: l)
            support = interpolate(xRange: [500, 1000], yRange: [5, 10], x: l)
        }
        else {
            confidence = 0.4
            support = 20
        }
        
        return (confidence, support)
    }
    
    private func extractValueWithRegex(pageSource: String, pattern: String) -> String? {
        let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive)
        if let match = regex?.firstMatch(in: pageSource, options: [], range: NSRange(location: 0, length: pageSource.utf16.count)) {
            if let valueRange = Range(match.range(at: 1), in: pageSource) {
                let value = pageSource[valueRange]
                return String(value)
            }
            return nil
        }
        return nil
    }
    
}

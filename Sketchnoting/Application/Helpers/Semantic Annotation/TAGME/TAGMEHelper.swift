//
//  TAGMEHelper.swift
//  Sketchnoting
//
//  Created by Aryobarzan on 26/08/2019.
//  Copyright © 2019 Aryobarzan. All rights reserved.
//

import UIKit
import Alamofire
import SwiftyJSON

class TAGMEHelper {
    
    func fetch(text: String, note: Sketchnote) {
        let chunks = text.split(by: 6000)
        
        for chunk in chunks {
            let parameters: Parameters = ["text": chunk, "lang": "en", "include_abstract": "true", "include_categories": "true", "gcube-token": "5f57008b-3114-47e9-9ee2-742c877d37b2-843339462"]
            let headers: HTTPHeaders = [
                "Accept": "application/json"
            ]
            AF.request("http://tagme.d4science.org/tagme/tag", parameters: parameters, headers: headers).responseJSON { response in
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
                
                if let annotations = json["annotations"].array {
                    for annotation in annotations {
                        if let spot = annotation["spot"].string, let id = annotation["id"].double, let abstract = annotation["abstract"].string, let title = annotation["title"].string {
                            if !spot.isEmpty && !abstract.isEmpty && results[spot] == nil {
                                results[spot] = spot
                                var categories = [String]()
                                if let categoriesArray = annotation["dbpedia_categories"].array {
                                    for category in categoriesArray {
                                        if let cat = category.string {
                                            categories.append(cat)
                                        }
                                    }
                                }
                                if let document = TAGMEDocument(title: title, description: abstract, URL: "tagme.d4science.org/tagme", type: .TAGME, previewImage: nil, spot: spot, categories: categories, wikiPageID: id) {
                                    note.addDocument(document: document)
                                    self.fetchWikipediaImage(note: note, document: document)
                                    
                                    KnowledgeGraphHelper.isPlace(name: title, completionHandler: { isPlace in
                                        if isPlace {
                                            MapHelper.fetchMap(location: title, document: document, note: note)
                                        }
                                        else {
                                            let placeTerms = ["place", "city", "populated", "country", "capital", "location"]
                                            for term in placeTerms {
                                                if document.description?.lowercased().contains(term) ?? false {
                                                    MapHelper.fetchMap(location: title, document: document, note: note)
                                                    break
                                                }
                                            }
                                            
                                        }
                                    })
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    private func fetchWikipediaImage(note: Sketchnote, document: TAGMEDocument) {
        let parameters: Parameters = ["action": "query", "prop": "info", "pageids": document.wikiPageID!, "inprop": "url", "format": "json"]
        let headers: HTTPHeaders = [
            "Accept": "application/json"
        ]
        AF.request("http://en.wikipedia.org/w/api.php", parameters: parameters, headers: headers).responseJSON { response in
            let responseResult = response.result
            var json = JSON()
            switch responseResult {
            case .success(let res):
                json = JSON(res)
            case .failure(let error):
                print(error.localizedDescription)
                KnowledgeGraphHelper.fetchWikipediaImage(note: note, document: document)
                return
            }
            if let wikiTitle = json["query"]["pages"][String(format: "%.0f", document.wikiPageID!)]["title"].string {
                let parameters: Parameters = ["action": "query", "prop": "pageimages", "format": "json", "piprop": "original", "titles": wikiTitle]
                let headers: HTTPHeaders = [
                    "Accept": "application/json"
                ]
                AF.request("http://en.wikipedia.org/w/api.php", parameters: parameters, headers: headers).responseJSON { response in
                    let responseResult = response.result
                    var json = JSON()
                    switch responseResult {
                    case .success(let res):
                        json = JSON(res)
                    case .failure(let error):
                        print(error.localizedDescription)
                        KnowledgeGraphHelper.fetchWikipediaImage(note: note, document: document)
                        return
                    }
                    var successful = false
                    if let imageURL = json["query"]["pages"][String(format: "%.0f", document.wikiPageID!)]["original"]["source"].string {
                        DispatchQueue.global().async {
                            if let url = URL(string: imageURL) {
                                if let data = try? Data(contentsOf: url) {
                                    DispatchQueue.main.async {
                                        print("Found wikipedia image for TAGME document.")
                                        if let image = UIImage(data: data) {
                                            note.setDocumentPreviewImage(document: document, image: image)
                                            successful = true
                                        }
                                    }
                                }
                                else {
                                    print("URL Wikipedia image not found for TAGME document.")
                                }
                            }
                        }
                    }
                    if !successful {
                        KnowledgeGraphHelper.fetchWikipediaImage(note: note, document: document)
                    }
                }
            }
        }
    }
}

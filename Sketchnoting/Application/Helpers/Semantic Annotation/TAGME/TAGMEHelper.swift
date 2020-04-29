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
    static var shared = TAGMEHelper()
    //var requestDelay: Double = 0
    private let tagmeQueue = DispatchQueue(label: "TAGMEQueue", qos: .background)
    func fetch(text: String, note: NoteX, parentConcept: TAGMEDocument? = nil) {
        let chunks = text.split(by: 6000)
        for chunk in chunks {
            let parameters: Parameters = ["text": chunk, "lang": "en", "include_abstract": "true", "include_categories": "true", "gcube-token": "5f57008b-3114-47e9-9ee2-742c877d37b2-843339462", "epsilon": note.tagmeEpsilon]
            let headers: HTTPHeaders = [
                "Accept": "application/json"
            ]

            AF.request("http://tagme.d4science.org/tagme/tag", parameters: parameters, headers: headers).responseJSON { response in
                self.tagmeQueue.async {
                    let responseResult = response.result
                    var json = JSON()
                    switch responseResult {
                    case .success(let res):
                        json = JSON(res)
                    case .failure(let error):
                        log.error(error.localizedDescription)
                        return
                    }
                    log.info("TAGME: API call successful.")
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
                                    if let document = TAGMEDocument(title: title, description: abstract, URL: "tagme.d4science.org/tagme", type: .TAGME, spot: spot, categories: categories, wikiPageID: id) {
                                        if let parentConcept = parentConcept {
                                            self.checkRelatedness(doc_one: parentConcept, doc_two: document, note: note)
                                        }
                                        else {
                                            self.performAdditionalSteps(document: document, note: note)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    private func performAdditionalSteps(document: TAGMEDocument, note: NoteX) {
        DispatchQueue.main.async {
            if !note.documents.contains(document) {
                log.info("TAGME: new document added - \(document.title)")
                note.addDocument(document: document)
                self.tagmeQueue.async {
                    self.fetchWikipediaIntroText(document: document)
                    self.fetchWikipediaImage(document: document, completion: {foundImage in
                        if !foundImage {
                            KnowledgeGraphHelper.fetchWikipediaImage(note: note, document: document)
                        }
                    })
                    KnowledgeGraphHelper.isPlace(name: document.title, completionHandler: { isPlace in
                        if isPlace {
                            MapHelper.fetchMap(location: document.title, document: document, note: note)
                        }
                        else {
                            let placeTerms = ["place", "city", "populated", "country", "capital", "location", "state", "village"]
                            for term in placeTerms {
                                if document.description?.lowercased().contains(term) ?? false {
                                    MapHelper.fetchMap(location: document.title, document: document, note: note)
                                    break
                                }
                            }
                            
                        }
                    })
                }
            }
        }
    }
    
    private func fetchWikipediaIntroText(document: TAGMEDocument) {
        if document.wikiPageID != nil {
            let parameters: Parameters = ["action": "query", "prop": "extracts", "exintro": "", "explaintext": "", "pageids": Int(document.wikiPageID!), "format": "json"]
            let headers: HTTPHeaders = [
                "Accept": "application/json"
            ]
            AF.request("http://en.wikipedia.org/w/api.php", parameters: parameters, headers: headers).responseJSON { response in
                let responseResult = response.result
                var json = JSON()
                switch responseResult {
                case .success(let res):
                    json = JSON(res)
                    if let wikiExtract = json["query"]["pages"][String(format: "%.0f", document.wikiPageID!)]["extract"].string {
                        DispatchQueue.main.async {
                            document.description = wikiExtract
                            log.info("Retrieved wikipedia intro extract for document \(document.title).")
                        }
                    }
                    break
                case .failure(let error):
                    log.error("Failed to retrieve wikipedia intro extract for document \(document.title).")
                    log.error(error.localizedDescription)
                    return
                }
            }
        }
    }
    
    private func fetchWikipediaImage(document: TAGMEDocument, completion:@escaping (Bool) -> ()) {
        if document.wikiPageID != nil {
            let parameters: Parameters = ["action": "query", "prop": "info", "pageids": Int(document.wikiPageID!), "inprop": "url", "format": "json"]
            let headers: HTTPHeaders = [
                "Accept": "application/json"
            ]
            AF.request("http://en.wikipedia.org/w/api.php", parameters: parameters, headers: headers).responseJSON { response in
                let responseResult = response.result
                var json = JSON()
                switch responseResult {
                case .success(let res):
                    json = JSON(res)
                    
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
                                
                                if let imageURL = json["query"]["pages"][String(format: "%.0f", document.wikiPageID!)]["original"]["source"].string {
                                    DispatchQueue.global(qos: .utility).async {
                                        if let url = URL(string: imageURL) {
                                            log.info("Found Wikipedia preview image for: \(document.title)")
                                            document.downloadImage(url: url, type: .Standard)
                                            completion(true)
                                        }
                                        else {
                                            completion(false)
                                        }
                                    }
                                }
                                else {
                                    completion(false)
                                }
                            case .failure(let error):
                                log.error(error.localizedDescription)
                                completion(false)
                                return
                            }
                        }
                    }
                    break
                case .failure(let error):
                    log.error(error.localizedDescription)
                    completion(false)
                    return
                }
            }
        }
        else {
            completion(false)
        }
    }
    
    func checkForSubconcepts(document: TAGMEDocument, note: NoteX) {
        self.tagmeQueue.async {
            let text = document.title.lowercased().replacingOccurrences(of: "\n", with: " ")
            var words = text.components(separatedBy: " ")
            var wordsToRemove = [String]()
            for word in words {
                if AnnotationUtilities.stopWordsEN.contains(word) {
                    wordsToRemove.append(word)
                }
            }
            words = words.filter { !wordsToRemove.contains($0) }
            if words.count > 1 {
                for word in words {
                    self.fetch(text: word, note: note, parentConcept: document)
                    log.info("Fetching TAGME document for subconcept: \(word)")
                }
            }
        }
    }
    
    func checkRelatedness(doc_one: TAGMEDocument, doc_two: TAGMEDocument, note: NoteX) {
        self.tagmeQueue.async {
            if doc_one != doc_two {
                if let id_one = doc_one.wikiPageID, let id_two = doc_two.wikiPageID {
                    let parameters: Parameters = ["id": "\(Int(id_one)) \(Int(id_two))", "lang": "en", "gcube-token": "5f57008b-3114-47e9-9ee2-742c877d37b2-843339462"]
                    let headers: HTTPHeaders = [
                        "Accept": "application/json"
                    ]
                    AF.request("http://tagme.d4science.org/tagme/rel", parameters: parameters, headers: headers).responseJSON { response in
                        let responseResult = response.result
                        var json = JSON()
                        switch responseResult {
                        case .success(let res):
                            json = JSON(res)
                        case .failure(let error):
                            log.error(error.localizedDescription)
                            return
                        }
                        log.info("TAGME: API call successful.")
                        log.info(json)
                        if let result = json["result"].array {
                            for res in result {
                                if let rel = res["rel"].double {
                                    if rel > 0.3 {
                                        log.info(rel)
                                        log.info(doc_two.title)
                                        self.performAdditionalSteps(document: doc_two, note: note)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

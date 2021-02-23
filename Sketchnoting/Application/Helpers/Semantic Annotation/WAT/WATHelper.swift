//
//  WATHelper.swift
//  Sketchnoting
//
//  Created by Aryobarzan on 03/05/2020.
//  Copyright © 2020 Aryobarzan. All rights reserved.
//

import UIKit
import Alamofire
import SwiftyJSON

class WATHelper {
    static var shared = WATHelper()
    private let gcube_token = "5f57008b-3114-47e9-9ee2-742c877d37b2-843339462"
    private let watQueue = DispatchQueue(label: "WATQueue", qos: .background)
    
    func fetch(text: String, note: (URL, Note), parentConcept: WATDocument? = nil) {
        let parameters: Parameters = ["text": text, "lang": "en", "tokenizer": "opennlp", "gcube-token": gcube_token]
        let headers: HTTPHeaders = [
            "Accept": "application/json"
        ]
        var documentsCount = 0
        AF.request("https://wat.d4science.org/wat/tag/tag", parameters: parameters, headers: headers).responseJSON { response in
            self.watQueue.async {
                let responseResult = response.result
                var json = JSON()
                switch responseResult {
                case .success(let res):
                    json = JSON(res)
                case .failure(let error):
                    log.error(error.localizedDescription)
                    return
                }
                log.info("WAT: API call successful.")
                var results = [String: String]()
                if let annotations = json["annotations"].array {
                    for annotation in annotations {
                        if documentsCount == 30 {
                            log.info("WAT: reached limit of 30 documents. Discarding the rest of the found annotations.")
                            break
                        }
                        if let spot = annotation["spot"].string, let id = annotation["id"].double, let title = annotation["title"].string?.replacingOccurrences(of: "_", with: " "), let rho = annotation["rho"].double {
                            if !spot.isEmpty && results[spot] == nil {
                                results[spot] = spot
                                if rho > 0.1 {
                                    if let document = WATDocument(title: title, description: "Missing description.", URL: "https://sobigdata.d4science.org/web/tagme/wat-api", type: .WAT, spot: spot, wikiPageID: id) {
                                        documentsCount += 1
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
    // to update
    private func performAdditionalSteps(document: WATDocument, note: (URL, Note)) {
        DispatchQueue.main.async {
            if !note.1.getDocuments().contains(document) {
                log.info("WAT: new document added - \(document.title)")
                note.1.addDocument(document: document)
                self.watQueue.async {
                    self.fetchWikipediaIntroText(document: document)
                    self.fetchWikipediaImage(document: document, completion: {foundImage in
                        if !foundImage {
                            KnowledgeGraphHelper.fetchWikipediaImage(document: document)
                        }
                    })
                    MapHelper.downloadMap(document: document)
                }
            }
        }
    }
    // To update
    private func fetchWikipediaIntroText(document: WATDocument) {
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
    // To update
    private func fetchWikipediaImage(document: WATDocument, completion:@escaping (Bool) -> ()) {
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
                        let parameters: Parameters = ["action": "query", "prop": "pageimages", "format": "json", "piprop": "thumbnail", "titles": wikiTitle, "pithumbsize": 200]
                        let headers: HTTPHeaders = [
                            "Accept": "application/json"
                        ]
                        AF.request("http://en.wikipedia.org/w/api.php", parameters: parameters, headers: headers).responseJSON { response in
                            let responseResult = response.result
                            var json = JSON()
                            switch responseResult {
                            case .success(let res):
                                json = JSON(res)
                                if let imageURL = json["query"]["pages"][String(format: "%.0f", document.wikiPageID!)]["thumbnail"]["source"].string {
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
    // To update
    func checkForSubconcepts(document: WATDocument, note: (URL, Note)) {
        self.watQueue.async {
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
                    log.info("Fetching WAT document for subconcept: \(word)")
                }
            }
        }
    }
    // To update
    func checkRelatedness(doc_one: WATDocument, doc_two: WATDocument, note: (URL, Note)) {
        self.watQueue.async {
            if doc_one != doc_two {
                if let id_one = doc_one.wikiPageID, let id_two = doc_two.wikiPageID {
                    let parameters: Parameters = ["id": "\(Int(id_one)) \(Int(id_two))", "lang": "en", "gcube-token": self.gcube_token]
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
                        log.info("WAT: API call successful.")
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

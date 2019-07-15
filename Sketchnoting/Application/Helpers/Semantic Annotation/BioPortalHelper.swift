//
//  BioPortalHelper.swift
//  Sketchnoting
//
//  Created by Aryobarzan on 05/07/2019.
//  Copyright © 2019 Aryobarzan. All rights reserved.
//

import UIKit
import Alamofire
import SwiftyJSON

class BioPortalHelper {
    let apikKey = "79790f4e-3333-477a-b9c2-7c0a815a62e0"
    var viewController: SketchNoteViewController!
    
    init?(viewController: SketchNoteViewController){
        self.viewController = viewController
    }
    
    func fetch(text: String) {
        let parameters: Parameters = ["apikey": apikKey, "input": text]
        let headers: HTTPHeaders = [
            "Accept": "application/json"
        ]
        AF.request("http://data.bioontology.org/recommender", parameters: parameters, headers: headers).responseJSON { response in
            switch response.result {
            case .success(let value):
                print("BioPortal Recommender successful call.")
                let json = JSON(value)
                
                if json.count > 0 {
                    if let ontologyAcronym = json[0]["ontologies"][0]["acronym"].string {
                        self.annotate(text: text, ontology: ontologyAcronym)
                    }
                }
            case .failure(let error):
                print(error.localizedDescription)
                return
            }
        }
    }
    
    private func annotate(text: String, ontology: String) {
        let parameters: Parameters = ["apikey": apikKey, "text": text, "ontologies": ontology]
        let headers: HTTPHeaders = [
            "Accept": "application/json"
        ]
        AF.request("http://data.bioontology.org/annotator", parameters: parameters, headers: headers).responseJSON { response in
            switch response.result {
            case .success(let value):
                print("BioPortal Annotator successful call.")
                
                let json = JSON(value)
                
                if json.count > 0 {
                    var classes = [String: String]() // annotation : ID
                    for x in json {
                        if let annotation = x.1["annotations"][0]["text"].string, let id = x.1["annotatedClass"]["@id"].string {
                            if classes[annotation] == nil {
                                classes[annotation] = id
                            }
                            if classes.count == 5 {
                                break
                            }
                        }
                    }
                    for c in classes {
                        self.fetchClass(class: c.key, id: c.value, ontology: ontology)
                    }
                }
            case .failure(let error):
                print(error.localizedDescription)
                return
            }
        }
    }
    private func fetchClass(class: String, id: String, ontology: String) {
        let parameters: Parameters = ["apikey": apikKey]
        let headers: HTTPHeaders = [
            "Accept": "application/json"
        ]
        AF.request("http://data.bioontology.org/ontologies/" + ontology + "/classes/" + id.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed)!, parameters: parameters, headers: headers).responseJSON { response in
            switch response.result {
            case .success(let value):
                print("BioPortal Class info successful call.")
                
                let json = JSON(value)
                
                if let label = json["prefLabel"].string, let definition = json["definition"][0].string {
                    print(label)
                    let document = Document(title: label, description: definition, entityType: "Biology", URL: "https://bioportal.bioontology.org/search?utf8=%E2%9C%93&query=" + (label.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed) ?? "https://bioportal.bioontology.org/"), type: .BioOntology, rank: Double(0))
                    if document != nil {
                        self.viewController.addDocument(document: document!)
                    }
                }
            case .failure(let error):
                print(error.localizedDescription)
                return
            }
        }
    }
}

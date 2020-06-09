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
    let apiKey = "79790f4e-3333-477a-b9c2-7c0a815a62e0"
    
    func fetch(text: String, note: Note) {
        let parameters: Parameters = ["apikey": apiKey, "input": text]
        let headers: HTTPHeaders = [
            "Accept": "application/json"
        ]
        AF.request("http://data.bioontology.org/recommender", parameters: parameters, headers: headers).responseJSON { response in
            switch response.result {
            case .success(let value):
                print("BioPortal Recommender: API call successful.")
                let json = JSON(value)
                
                if json.count > 0 {
                    if let ontologyAcronym = json[0]["ontologies"][0]["acronym"].string {
                        if ontologyAcronym.lowercased() != "chebi" {
                            self.annotate(text: text, ontology: ontologyAcronym, note: note)
                        }
                    }
                }
            case .failure(let error):
                print(error.localizedDescription)
                return
            }
        }
    }
    
    func fetchCHEBI(text: String, note: Note) {
        self.annotate(text: text, ontology: "CHEBI", note: note)
    }
    
    private func annotate(text: String, ontology: String, note: Note) {
        let parameters: Parameters = ["apikey": apiKey, "text": text, "ontologies": ontology, "include": "prefLabel,definition"]
        let headers: HTTPHeaders = [
            "Accept": "application/json"
        ]
        AF.request("http://data.bioontology.org/annotator", parameters: parameters, headers: headers).responseJSON { response in
            switch response.result {
            case .success(let value):
                print("BioPortal: API call successful.")
                
                let json = JSON(value)
                if json.count > 0 {
                    var classes = [String: String]() // annotation : ID
                    var documents = [Document]()
                    for x in json {
                        if let annotation = x.1["annotations"][0]["text"].string, let id = x.1["annotatedClass"]["@id"].string, let prefLabel = x.1["annotatedClass"]["prefLabel"].string, let definition = x.1["annotatedClass"]["definition"][0].string {
                            if classes[annotation] == nil {
                                classes[annotation] = id
                                
                                if ontology.lowercased() == "chebi" {
                                     let document = CHEBIDocument(title: annotation, description: definition, URL: "https://bioportal.bioontology.org/search?utf8=%E2%9C%93&query=" + (prefLabel.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed) ?? "https://bioportal.bioontology.org/"), type: .Chemistry, prefLabel: prefLabel, definition: definition, moleculeImage: nil)
                                    if let document = document {
                                        documents.append(document)
                                        self.fetchMoleculeImageForCHEBI(document: document, id: id, note: note)
                                    }
                                }
                                else {
                                    let document = BioPortalDocument(title: annotation, description: definition, URL: "https://bioportal.bioontology.org/search?utf8=%E2%9C%93&query=" + (prefLabel.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed) ?? "https://bioportal.bioontology.org/"), type: .BioPortal, prefLabel: prefLabel, definition: definition)
                                    if let document = document {
                                        documents.append(document)
                                    }
                                }
                            }
                            if classes.count == 10 {
                                break
                            }
                        }
                    }
                    DispatchQueue.main.async {
                        for doc in documents {
                            print("BioPortal/CHEBI: new document added - \(doc.title)")
                            note.addDocument(document: doc)
                        }
                    }
                }
            case .failure(let error):
                print(error.localizedDescription)
                return
            }
        }
    }
    
    private func fetchMoleculeImageForCHEBI(document: CHEBIDocument!, id: String, note: Note) {
        let regex = try? NSRegularExpression(pattern: "http://purl.obolibrary.org/obo/CHEBI_([0-9]*)", options: .caseInsensitive)
        if let match = regex?.firstMatch(in: id, options: [], range: NSRange(location: 0, length: id.utf16.count)) {
            if let valueRange = Range(match.range(at: 1), in: id) {
                let value = id[valueRange].lowercased()
                
                DispatchQueue.global().async {
                    if let url = URL(string: "https://www.ebi.ac.uk/chebi/displayImage.do?defaultImage=true&imageIndex=0&chebiId=" + value + "&dimensions=900") {
                        document.downloadImage(url: url, type: .Molecule)
                        log.info("CHEBI: molecule image added - \(document.title)")
                    }
                    else {
                        log.error("URL CHEBI image not found.")
                    }
                }
            }
        }
    }
}

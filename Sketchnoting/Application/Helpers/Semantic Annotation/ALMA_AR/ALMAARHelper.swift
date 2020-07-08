//
//  ALMAARHelper.swift
//  Sketchnoting
//
//  Created by Aryobarzan on 04/07/2020.
//  Copyright © 2020 Aryobarzan. All rights reserved.
//

import UIKit
import Alamofire
import SwiftyJSON

class ALMAARHelper {
    static var shared = ALMAARHelper()
    private let almaarQueue = DispatchQueue(label: "ALMAARQueue", qos: .background)
    func fetch(concept: String, spot: String, note: (URL, Note)) {
        let concept_sanitized = concept.replacingOccurrences(of: " ", with: "_")
        let parameters: Parameters = [:]
        let headers: HTTPHeaders = [
            "Accept": "application/json"
        ]
        AF.request("https://alma.uni.lu/api/concepts/dbr:\(concept_sanitized)/resources/", parameters: parameters, headers: headers).responseJSON { response in
            self.almaarQueue.async {
                let responseResult = response.result
                var json = JSON()
                switch responseResult {
                case .success(let res):
                    json = JSON(res)
                case .failure(let error):
                    log.error(error.localizedDescription)
                    return
                }
                log.info("ALMA AR (ID): API call successful.")
                if let matches = json.array {
                    for match in matches {
                        if let id = match["id"].int, let _ = match["type"].string, let _ = match["url"].string {
                            self.fetchResource(id: id, concept: concept, spot: spot, note: note)
                        }
                    }
                }
            }
        }
    }
    
    private func fetchResource(id: Int, concept: String, spot: String, note: (URL, Note)) {
        let parameters: Parameters = [:]
        let headers: HTTPHeaders = [
            "Accept": "application/json"
        ]
        AF.request("https://alma.uni.lu/api/resources/\(id)/", parameters: parameters, headers: headers).responseJSON { response in
            self.almaarQueue.async {
                let responseResult = response.result
                var json = JSON()
                switch responseResult {
                case .success(let res):
                    json = JSON(res)
                case .failure(let error):
                    log.error(error.localizedDescription)
                    return
                }
                log.info("ALMA AR (Resource): API call successful.")
                if let id = json["id"].int, let title = json["title"].string, let previewURL = json["previewURL"].string, let url = json["url"].string {
                    if let document = ARDocument(title: title, description: nil, URL: url, type: .ALMAAR, spot: spot, categories: [String](), wikiPageID: nil)  { // Wiki page ID same as id?
                        DispatchQueue.main.async {
                            note.1.addDocument(document: document)
                            DispatchQueue.global(qos: .utility).async {
                                if let url = URL(string: previewURL) {
                                    log.info("Found ALMA AR document preview image for: \(document.title)")
                                    document.downloadImage(url: url, type: .Standard)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

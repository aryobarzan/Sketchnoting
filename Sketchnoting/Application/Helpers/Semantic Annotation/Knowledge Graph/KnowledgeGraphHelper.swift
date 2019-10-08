//
//  KnowledgeGraphHelper.swift
//  Sketchnoting
//
//  Created by Aryobarzan on 04/09/2019.
//  Copyright © 2019 Aryobarzan. All rights reserved.
//

import UIKit
import Alamofire
import SwiftyJSON

class KnowledgeGraphHelper {
    static let apiKey: String = "AIzaSyAY_tyXihgPFbOktnv9RxP7HFmP-dshf98"
    
    public static func isPlace(name: String, completionHandler:@escaping (Bool) -> ()) {
        let parameters: Parameters = ["query": name, "key": apiKey, "limit": 1]
        let headers: HTTPHeaders = [
            "Accept": "application/json"
        ]
        AF.request("https://kgsearch.googleapis.com/v1/entities:search", parameters: parameters, headers: headers).responseJSON { response in
            let responseResult = response.result
            var json = JSON()
            switch responseResult {
            case .success(let res):
                json = JSON(res)
            case .failure(let error):
                print(error.localizedDescription)
                return
            }
            if json["itemListElement"].exists() && json["itemListElement"].array != nil && json["itemListElement"].array!.count > 0 {
                if let typeArray = json["itemListElement"].array?[0]["result"]["@type"].array {
                    for type in typeArray {
                        if let value = type.string {
                            if value.lowercased().contains("place") {
                                print("Knowledge Graph Helper: Is a place - \(name)")
                                completionHandler(true)
                                return
                            }
                        }
                    }
                }
            }
            completionHandler(false)
        }
    }
    
    public static func fetchWikipediaImage(note: Sketchnote, document: Document) {
        let parameters: Parameters = ["query": document.title, "key": apiKey, "limit": 1]
        let headers: HTTPHeaders = [
            "Accept": "application/json"
        ]
        AF.request("https://kgsearch.googleapis.com/v1/entities:search", parameters: parameters, headers: headers).responseJSON { response in
            let responseResult = response.result
            var json = JSON()
            switch responseResult {
            case .success(let res):
                json = JSON(res)
            case .failure(let error):
                print(error.localizedDescription)
                return
            }
            
             if json["itemListElement"].exists() && json["itemListElement"].array != nil && json["itemListElement"].array!.count > 0 {
                if let imageString = json["itemListElement"].array?[0]["result"]["image"]["contentUrl"].string {
                    DispatchQueue.global().async {
                        if let url = URL(string: imageString) {
                            document.downloadImage(url: url, type: .Standard)
                            log.info("Knowledge Graph: Preview image added - \(document.title)")
                        }
                        else {
                            log.error("URL Wikipedia image not found via Knowledge Graph for TAGME document.")
                        }
                    }
                }
            }
            
        }
    }
}

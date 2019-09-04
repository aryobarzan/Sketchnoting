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
            }
            if let typeArray = json["itemListElement"].array?[0]["result"]["@type"].array {
                for type in typeArray {
                    if let value = type.string {
                        if value.lowercased().contains("place") {
                            completionHandler(true)
                            return
                        }
                    }
                }
            }
            completionHandler(false)
        }
    }
}

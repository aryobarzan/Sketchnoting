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
    var viewController: SketchNoteViewController!
    
    init?(viewController: SketchNoteViewController){
        self.viewController = viewController
    }
    
    func fetch(text: String) {
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
                                    self.viewController.displayInBookshelf(document: document)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

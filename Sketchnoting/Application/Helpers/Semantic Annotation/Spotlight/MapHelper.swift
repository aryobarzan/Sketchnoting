//
//  MapHelper.swift
//  Sketchnoting
//
//  Created by Aryobarzan on 04/07/2019.
//  Copyright © 2019 Aryobarzan. All rights reserved.
//

import UIKit
import Alamofire

class MapHelper {
    static func fetchMap(location: String, document: Document, note: Sketchnote) {
        let parameters: Parameters = ["q": location, "maxRows": 1, "username": "aryo"]
        let headers: HTTPHeaders = [
                "Accept": "application/json"
        ]
        AF.request("http://api.geonames.org/searchJSON", parameters: parameters, headers: headers).responseJSON { response in
            let responseResult = response.result
            var json = [String : Any]()
            switch responseResult {
            case .success(let res):
                json = res as! [String: Any]
            case .failure(let error):
                print(error.localizedDescription)
            }
            print("JSON: \(json)")
                
            let result = json
            let resources = result["geonames"] as? [[String: Any]]
            if resources != nil {
                for res in resources! {
                    let latitude = res["lat"] as! String
                    let longitude = res["lng"] as! String
                    self.fetchMapImage(latitude: latitude, longitude: longitude, document: document, note: note)
                }
            }
            else {
                print("geonames didn't work")
            }
        }
    }
    static func fetchMapImage(latitude: String, longitude: String, document: Document, note: Sketchnote) {
        let url = URL(string: "https://www.mapquestapi.com/staticmap/v5/map?key=bAELaFV3A8vNwICyhbziI7tNeSfYdUvr&center=" + latitude + "," + longitude + "&size=800,600")
        
        DispatchQueue.global().async {
            if let data = try? Data(contentsOf: url!) {
                DispatchQueue.main.async {
                    print("Found map image for document.")
                    if let image = UIImage(data: data) {
                        print("Setting map image for document.")
                        note.setDocumentMapImage(document: document, image: image)
                    }
                }
            }
            else {
                print("URL map image not found.")
            }
        }
    }
}

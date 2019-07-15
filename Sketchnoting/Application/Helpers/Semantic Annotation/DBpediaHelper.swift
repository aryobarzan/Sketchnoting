//
//  DBpediaHelper.swift
//  Sketchnoting
//
//  Created by Aryobarzan on 08/07/2019.
//  Copyright © 2019 Aryobarzan. All rights reserved.
//

import UIKit
import Alamofire

class DBpediaHelper {
    var viewController: SketchNoteViewController!
    
    init?(viewController: SketchNoteViewController){
        self.viewController = viewController
    }
    
    func fetch(text: String) {
        let chunks = text.split(by: 6000)
        
        for chunk in chunks {
            let (confidence, _) = calculate_confidence_support(l: Double(chunk.count))
            let parameters: Parameters = ["text": chunk, "confidence": confidence]
            let headers: HTTPHeaders = [
                "Accept": "application/json"
            ]
            AF.request("http://api.dbpedia-spotlight.org/en/annotate", parameters: parameters, headers: headers).responseJSON { response in
                let responseResult = response.result
                var json = [String : Any]()
                switch responseResult {
                case .success(let res):
                    json = res as! [String: Any]
                case .failure(let error):
                    print(error.localizedDescription)
                }
                print("JSON: \(json)")
                var results = [String: String]()
                var documents = [Document]()
                let result = json
                let resources = result["Resources"] as? [[String: Any]]
                if resources != nil {
                    for res in resources! {
                        let concept = res["@surfaceForm"] as! String
                        let conceptURL = res["@URI"] as! String
                        let rankPercentage = Double(res["@percentageOfSecondRank"] as! String)
                        if results[concept] == nil && !concept.isEmpty {
                            if !conceptURL.isEmpty {
                                results[concept] = conceptURL
                                
                                var description = ""
                                var entityType = ""
                                let url = URL(string: conceptURL)
                                if url != nil {
                                    do {
                                        let html = try NSString(contentsOf: url!, encoding: String.Encoding.utf8.rawValue)
                                        let abstract = self.extractValueWithRegex(pageSource: html as String, pattern: "<li><span class=\"literal\"><span property=\"dbo:abstract\" xmlns:dbo=\"http://dbpedia.org/ontology/\" xml:lang=\"en\">(.*)</span>")
                                        if abstract != nil {
                                            description = abstract?.htmlAttributedString?.string ?? ""
                                        }
                                        
                                        let dboType = self.extractValueWithRegex(pageSource: html as String, pattern: "An Entity of Type : <a href=.*>(.*)</a>,")
                                        if dboType != nil {
                                            entityType = dboType ?? ""
                                        }
                                    } catch {
                                    }
                                }
                                let document = Document(title: concept, description: description, entityType: entityType, URL: conceptURL, type: .Spotlight, rank: rankPercentage ?? Double(0))
                                if document != nil {
                                    documents.append(document!)
                                }
                            }
                        }
                    }
                    self.viewController.displaySpotlightDocuments(documents: documents)
                    let bioportalHelper = BioPortalHelper(viewController: self.viewController)
                    bioportalHelper?.fetch(text: text)
                }
                else {
                    self.viewController.displayNoDocumentsFound()
                }
            }
        }
    }
    
    private func get_slope_intercept(x1: Double, x2: Double, y1: Double, y2: Double) -> (Double, Double) {
        let slope = (y2 - y1) / (x2 - x1)
        let intercept = y1 - slope * x1
        return (slope, intercept)
    }
    
    
    private func interpolate(xRange: [Double], yRange: [Double], x: Double) -> Double {
        let (slope, intercept) = get_slope_intercept(x1: xRange[0], x2: xRange[1], y1: yRange[0], y2: yRange[1])
        let y = slope * x + intercept
        return y
    }
    
    private func calculate_confidence_support(l: Double) -> (Double, Double) {
        var confidence = 0.5
        var support = 20.0
        if (0 ... 500).contains(l) {
            confidence = interpolate(xRange: [0, 500], yRange: [0.1, 0.25], x: l)
            support = interpolate(xRange: [0, 500], yRange: [5, 10], x: l)
        }
        else if (500 ... 1000).contains(l) {
            confidence = interpolate(xRange: [500, 1000], yRange: [0.2, 0.35], x: l)
            support = interpolate(xRange: [500, 1000], yRange: [5, 10], x: l)
        }
        else {
            confidence = 0.4
            support = 20
        }
        
        return (confidence, support)
    }
    
    private func extractValueWithRegex(pageSource: String, pattern: String) -> String? {
        let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive)
        if let match = regex?.firstMatch(in: pageSource, options: [], range: NSRange(location: 0, length: pageSource.utf16.count)) {
            if let valueRange = Range(match.range(at: 1), in: pageSource) {
                let value = pageSource[valueRange].lowercased()
                return value
            }
            return nil
        }
        return nil
    }
    
}

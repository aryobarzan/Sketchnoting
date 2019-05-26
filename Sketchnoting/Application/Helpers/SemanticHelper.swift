//
//  SemanticHelper.swift
//  Sketchnoting
//
//  Created by Aryobarzan on 27/02/2019.
//  Copyright © 2019 Aryobarzan. All rights reserved.
//

import UIKit
import Alamofire

// The functions for calling the DBpedia Spotlight API (used for semantic annotation, i.e. for retrieving documents related to a note's text) are contained in this file
// The functions are static to make them accessible across the application and not just in the SketchNoteViewController.
// Additionally, a static alamofire* session has been created to avoid a performance degradation, as the application would only be making a single call at a given time either way.
// *Alamofire is a third party library that facilitates http requests

class SemanticHelper {
    
    private static var Manager : Alamofire.Session = {
        let configuration = URLSessionConfiguration.default
        
        var proxyConfiguration = [String: AnyObject]()
        proxyConfiguration.updateValue(1 as AnyObject, forKey: "HTTPEnable")
        proxyConfiguration.updateValue("connect.virtual.uniandes.edu.co" as AnyObject, forKey: "HTTPProxy")
        proxyConfiguration.updateValue(22 as AnyObject, forKey: "HTTPPort")
        proxyConfiguration.updateValue(1 as AnyObject, forKey: "HTTPSEnable")
        proxyConfiguration.updateValue("connect.virtual.uniandes.edu.co" as AnyObject, forKey: "HTTPSProxy")
        proxyConfiguration.updateValue(22 as AnyObject, forKey: "HTTPSPort")
        configuration.connectionProxyDictionary = proxyConfiguration
        let man = Alamofire.Session(
            configuration: configuration
        )
        return man
    }()
    
    static func performSpotlightOnSketchnote(text: String, viewController: SketchNoteViewController) {
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
                                    
                                    // Fetch the abstract text and entity type (e.g. person, place) from the found resource's page source
                                    var description = ""
                                    var entityType = ""
                                    let url = URL(string: conceptURL)
                                    if url != nil {
                                        do {
                                            let html = try NSString(contentsOf: url!, encoding: String.Encoding.utf8.rawValue)
                                            let abstract = extractValueWithRegex(pageSource: html as String, pattern: "<li><span class=\"literal\"><span property=\"dbo:abstract\" xmlns:dbo=\"http://dbpedia.org/ontology/\" xml:lang=\"en\">(.*)</span>")
                                            if abstract != nil {
                                                description = abstract ?? ""
                                            }
                                            
                                            let dboType = extractValueWithRegex(pageSource: html as String, pattern: "An Entity of Type : <a href=.*>(.*)</a>,")
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
                        viewController.displaySpotlightDocuments(documents: documents)
                    }
                    else {
                        viewController.displayNoDocumentsFound()
                    }
            }
        }
    }
    
    private static func get_slope_intercept(x1: Double, x2: Double, y1: Double, y2: Double) -> (Double, Double) {
        let slope = (y2 - y1) / (x2 - x1)
        let intercept = y1 - slope * x1
        return (slope, intercept)
    }
    
    
    private static func interpolate(xRange: [Double], yRange: [Double], x: Double) -> Double {
        let (slope, intercept) = get_slope_intercept(x1: xRange[0], x2: xRange[1], y1: yRange[0], y2: yRange[1])
        let y = slope * x + intercept
        return y
    }
    
    private static func calculate_confidence_support(l: Double) -> (Double, Double) {
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
    
    private static func extractValueWithRegex(pageSource: String, pattern: String) -> String? {
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

extension String {
    func split(by length: Int) -> [String] {
        var startIndex = self.startIndex
        var results = [Substring]()
        
        while startIndex < self.endIndex {
            let endIndex = self.index(startIndex, offsetBy: length, limitedBy: self.endIndex) ?? self.endIndex
            results.append(self[startIndex..<endIndex])
            startIndex = endIndex
        }
        
        return results.map { String($0) }
    }
}

extension String {
    subscript(_ range: CountableRange<Int>) -> String {
        let idx1 = index(startIndex, offsetBy: max(0, range.lowerBound))
        let idx2 = index(startIndex, offsetBy: min(self.count, range.upperBound))
        return String(self[idx1..<idx2])
    }
}

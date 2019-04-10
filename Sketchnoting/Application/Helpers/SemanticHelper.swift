//
//  SemanticHelper.swift
//  Sketchnoting
//
//  Created by Aryobarzan on 27/02/2019.
//  Copyright © 2019 Aryobarzan. All rights reserved.
//

import UIKit
import Alamofire

class SemanticHelper {
    
    static func HTTPsendRequest(request: URLRequest,
                         callback: @escaping (Error?, String?) -> Void) {
        let task = URLSession.shared.dataTask(with: request) { (data, res, err) in
            if (err != nil) {
                callback(err,nil)
            } else {
                callback(nil, String(data: data!, encoding: String.Encoding.utf8))
            }
        }
        task.resume()
    }
    
    // post JSON
    static func HTTPPostJSON(url: String,  data: Data,
                      callback: @escaping (Error?, String?) -> Void) {
        
        var request = URLRequest(url: URL(string: url)!)
        
        request.httpMethod = "POST"
        request.addValue("application/json",forHTTPHeaderField: "Content-Type")
        request.addValue("application/json",forHTTPHeaderField: "Accept")
        request.httpBody = data
        HTTPsendRequest(request: request, callback: callback)
    }
    
   /* private static func jsonRequest(URL2: String, data: [String: Any]) -> [String: Any]? {
        let json: [String: Any] = data
        
        let jsonData = try? JSONSerialization.data(withJSONObject: json)
        // create post request
        let url = URL(string: URL2)!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        // insert json data to the request
        request.httpBody = jsonData
        
        var r: [String: Any]?

        let config = URLSessionConfiguration.default
        config.requestCachePolicy = URLRequest.CachePolicy.reloadIgnoringLocalCacheData
        config.connectionProxyDictionary = [AnyHashable: Any]()
        config.connectionProxyDictionary?[kCFNetworkProxiesHTTPEnable as String] = 1
        config.connectionProxyDictionary?[kCFNetworkProxiesHTTPProxy as String] = "connect.virtual.uniandes.edu.co"
        config.connectionProxyDictionary?[kCFNetworkProxiesHTTPPort as String] = 22
        config.connectionProxyDictionary?[kCFStreamPropertyHTTPSProxyHost as String] = "connect.virtual.uniandes.edu.co"
        config.connectionProxyDictionary?[kCFStreamPropertyHTTPSProxyPort as String] = 22
        
        let session = URLSession.init(configuration: config, delegate: nil, delegateQueue: OperationQueue.current)
        
        let task = session.dataTask(with: request) {
            (data: Data?, response: URLResponse?, error: Error?) in
            if error != nil {
                NSLog("Client-side error in request to \(url): \(error)")
                return
            }
            
            if data == nil {
                NSLog("Data from request to \(url) is nil")
                return
            }
            
            let httpResponse = response as? HTTPURLResponse
            if httpResponse?.statusCode != 200 {
                NSLog("Server-side error in request to \(url): \(httpResponse)")
                return
            }
            
            print("Success")
            session.invalidateAndCancel()
        }
        
        task.resume()
        return r
    }*/
    
    static func frequencyService(URL: String, dataImmutable: [String: Any], chunkSize: Int = 6000) -> [String: Int] {
        let text = dataImmutable["text"] as! String
        let chunks = text.split(by: chunkSize)
        
        var data = dataImmutable
        var results = [String: Int]()
        
        for chunk in chunks {
            data["text"] = chunk
            print(chunk)
            AF.request("https://babelfy.io/v1/disambiguate?text=" + chunk.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed)! + "&lang=EN&key=f940e5b5-35a0-4dce-bcad-c3756e8eaad2").responseJSON { response in
                print("Request: \(String(describing: response.request))")   // original url request
                print("Response: \(String(describing: response.response))") // http url response
                print("Result: \(response.result)")                         // response serialization result
                
                if let json = response.result.value {
                    print("JSON: \(json)") // serialized json response
                }
                
                if let data = response.data, let utf8Text = String(data: data, encoding: .utf8) {
                    print("Data: \(utf8Text)") // original server data as UTF8 string
                }
            }

            //let r: [String: Any] = jsonRequest(URL2: URL, data: data) ?? [String: Any]()
            
            /*for (concept, frequency) in r {
                if results[concept] == nil {
                    results[concept] = 0
                }
                let f = frequency as! Int
                results[concept] = results[concept]! + f
            }*/
        }
        return results
    }
    
    /*static func babelfy(text: String, documentsView: DocumentsViewController, textNote: TextNote) {
        /*var data = [String: Any]()
        data["text"] = text
        data["language"] = "EN"
        let results = frequencyService(URL: "http://172.24.99.127:8082/babelfy", dataImmutable: data)
        print(results)
        for (concept, f) in results {
            print(concept + " - " + String(f))
        }*/
        let chunks = text.split(by: 6000)
        
        var results = [String: String]()
        
        for chunk in chunks {
            AF.request("https://babelfy.io/v1/disambiguate?text=" + chunk.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed)! + "&lang=EN&key=f940e5b5-35a0-4dce-bcad-c3756e8eaad2").responseJSON { response in
                
                if let json = response.result.value {
                    print("JSON: \(json)")
                    
                    let result = json as! [[String: Any]]
                    for item in result {
                        let coherenceScore = item["coherenceScore"] as! Double
                        let score = item["score"] as! Double
                        if coherenceScore >= 0.4 || score >= 0.4 {
                            let startIndex = (item["charFragment"] as! [String: Int])["start"]
                            let endIndex = (item["charFragment"] as! [String: Int])["end"]
                            
                            let concept = chunk[startIndex!..<(endIndex!+1)]
                            let conceptURL = item["DBpediaURL"] as! String
                            if results[concept] == nil && !concept.isEmpty {
                                if !conceptURL.isEmpty {
                                    results[concept] = conceptURL
                                    documentsView.addBabelfyDocument(title: concept, url: conceptURL)
                                    let document = Document(title: concept, description: nil, URL: conceptURL, type: DocumentType.Babelfy)
                                    textNote.addDocument(document: document!)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    static func spotlight(text: String, documentsView: DocumentsViewController, textNote: TextNote) {
        let chunks = text.split(by: 6000)
        
        var results = [String: String]()
        
        for chunk in chunks {
            let parameters: Parameters = ["text": chunk, "confidence": 0.6]
            let headers: HTTPHeaders = [
                "Accept": "application/json"
            ]
            AF.request("http://api.dbpedia-spotlight.org/en/annotate", parameters: parameters, headers: headers).responseJSON { response in
                if let json = response.result.value {
                    print("JSON: \(json)")
                    
                    let result = json as! [String: Any]
                    let resources = result["Resources"] as? [[String: Any]]
                    if resources != nil {
                        let concept = resources![0]["@surfaceForm"] as! String
                        let conceptURL = resources![0]["@URI"] as! String
                        if results[concept] == nil && !concept.isEmpty {
                            if !conceptURL.isEmpty {
                                results[concept] = conceptURL
                                documentsView.addSpotlightDocument(title: concept, url: conceptURL)
                                let document = Document(title: concept, description: nil, URL: conceptURL, type: DocumentType.Babelfy)
                                textNote.addDocument(document: document!)
                            }
                        }
                    }
                }
            }
        }
    }*/
    private static var Manager : Alamofire.Session = {
        let configuration = URLSessionConfiguration.default
        //configuration.httpAdditionalHeaders = Session.default
        
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
    
    static private func babelfy2(text: String) {
        let parameters: Parameters = ["text": text, "language": "EN"]
        let headers: HTTPHeaders = [
            "Accept": "application/json"
        ]
        Manager.request("http://172.24.99.127:8082/babelfy", method: .post, parameters: parameters, encoding: URLEncoding(destination: .queryString), headers: headers).responseJSON { response in
            if let json = response.result.value {
                print(json)
            }
            print(response.debugDescription)
        }
    }
    
    static func performBabelfyOnSketchnote(text: String, viewController: SketchNoteViewController) {
        let parameters: Parameters = ["text": text, "language": "EN"]
        let headers: HTTPHeaders = [
            "Accept": "application/json"
        ]
        Manager.request("http://172.24.99.127:8082/babelfy", method: .post, parameters: parameters, encoding: URLEncoding(destination: .queryString), headers: headers).responseJSON { response in
            if let json = response.result.value {
                let result = json as! NSArray
                print(result)
                viewController.displayBabelfyDocuments(text: text, json: result)
            }
        }
    }
    
    static func performSpotlightOnSketchnote(text: String, viewController: SketchNoteViewController) {
        let chunks = text.split(by: 6000)
        
        for chunk in chunks {
            let (confidence, _) = calculate_confidence_support(l: Double(chunk.count))
            let parameters: Parameters = ["text": chunk, "confidence": confidence]
            let headers: HTTPHeaders = [
                "Accept": "application/json"
            ]
            AF.request("http://api.dbpedia-spotlight.org/en/annotate", parameters: parameters, headers: headers).responseJSON { response in
                if let json = response.result.value {
                    print("JSON: \(json)")
                    var results = [String: String]()
                    var documents = [Document]()
                    let result = json as! [String: Any]
                    let resources = result["Resources"] as? [[String: Any]]
                    if resources != nil {
                        for res in resources! {
                            let concept = res["@surfaceForm"] as! String
                            let conceptURL = res["@URI"] as! String
                            let rankPercentage = Double(res["@percentageOfSecondRank"] as! String)
                            if results[concept] == nil && !concept.isEmpty {
                                if !conceptURL.isEmpty {
                                    results[concept] = conceptURL
                                    
                                    // Fetch a short description
                                    var description = ""
                                    let url = URL(string: conceptURL)
                                    if url != nil {
                                        do {
                                            let html = try NSString(contentsOf: url!, encoding: String.Encoding.utf8.rawValue)
                                            if let regex = try? NSRegularExpression(pattern: "<li><span class=\"literal\"><span property=\"dbo:abstract\" xmlns:dbo=\"http://dbpedia.org/ontology/\" xml:lang=\"en\">.*</span>", options: .caseInsensitive)
                                            {
                                                
                                                let matches = regex.matches(in: html as String, options: [], range: NSRange(location: 0, length: html.length)).map {
                                                    html.substring(with: $0.range)
                                                }
                                                if matches.count > 0 {
                                                    description = matches[0].replacingOccurrences(of: "<li><span class=\"literal\"><span property=\"dbo:abstract\" xmlns:dbo=\"http://dbpedia.org/ontology/\" xml:lang=\"en\">", with: "").replacingOccurrences(of: "</span>", with: "")
                                                }
                                            }
                                        } catch {
                                        }
                                    }
                                    let document = Document(title: concept, description: description, URL: conceptURL, type: .Spotlight, rank: rankPercentage ?? Double(0))
                                    if document != nil {
                                        documents.append(document!)
                                    }
                                }
                            }
                        }
                        viewController.displaySpotlightDocuments(documents: documents)
                    }
                }
            }
        }
    }
    static func performSpotlightUniandesOnSketchnote(text: String, viewController: SketchNoteViewController) {
        let (confidence, support) = calculate_confidence_support(l: Double(text.count))
        print("confidence \(confidence)")
        print("support \(support)")

        let parameters: Parameters = ["text": text, "language": "EN", "confidence": confidence, "support": support, "canonical": 1]
        let headers: HTTPHeaders = [
            "Accept": "application/json"
        ]
        Manager.request("http://172.24.99.127:8081/spotlight", method: .post, parameters: parameters, encoding: URLEncoding(destination: .queryString), headers: headers).responseJSON { response in
            if let json = response.result.value {
                let result = json as! NSArray
                print(result)
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

}



// https://stackoverflow.com/questions/32212220/how-to-split-a-string-into-substrings-of-equal-length
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

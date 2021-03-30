//
//  SKTextRank.swift
//  Sketchnoting
//
//  Created by Aryobarzan on 22/03/2021.
//  Copyright © 2021 Aryobarzan. All rights reserved.
//

import UIKit
import NaturalLanguage

import SwiftGraph

class SKTextRank {
    static var shared = SKTextRank()
    private init() {}
    
    func extractKeywords(text: String, numberOfKeywords: Int = 10, biased: Bool = true, usePostProcessing: Bool = true) -> [String] {
        let partsOfSpeech = SemanticSearch.shared.tag(text: text, scheme: .lexicalClass)
        let nounsAndAdjectives = partsOfSpeech.filter { $0.0.count > 2 }.filter { $0.1 == NLTag.noun.rawValue || $0.1 == NLTag.adjective.rawValue || $0.1 == NLTag.other.rawValue }.map { SemanticSearch.shared.lemmatize(text: $0.0.lowercased()) }.filter { !stopwords.contains($0) }

        let graph = WeightedGraph<String, Double>()
        var addedVertices = [String : Int]()
        for w in Array(Set(nounsAndAdjectives)) {
            let index = graph.addVertex(w)
            addedVertices[w] = index
        }
        for (i, word) in nounsAndAdjectives.enumerated() {
            let index = addedVertices[word]!
            let N = 3
            let minIndex = max(0, i-N)
            let maxIndex = min(nounsAndAdjectives.count, i+N)
            for w in nounsAndAdjectives[minIndex..<maxIndex] {
                if w == word {
                    continue
                }
                if !graph.edgeExists(fromIndex: index, toIndex: addedVertices[w]!) && !graph.edgeExists(fromIndex: addedVertices[w]!, toIndex: index){
                    if biased {
                        let weight = 2.0 - SemanticSearch.shared.wordDistance(between: word, and: w)
                        if weight > 0.65 {
                            graph.addEdge(fromIndex: index, toIndex: addedVertices[w]!, weight: 1.0, directed: false)
                        }
                    }
                    else {
                        graph.addEdge(fromIndex: index, toIndex: addedVertices[w]!, weight: 1.0, directed: false)
                    }
                }
            }
        }
        
        let scores = iterate(graph: graph)
        let topKeywords = scores.sorted { x, y in
            x.1 > y.1
        }.slice(length: numberOfKeywords)
        if usePostProcessing {
            let postprocessedTopKeywords = postprocess(keywords: topKeywords.map { $0.0 }, partsOfSpeech: partsOfSpeech.map {($0.0.lowercased(), $0.1)})
            return postprocessedTopKeywords
        }
        else {
            return topKeywords.map { $0.0 }
        }
        //let temp = partsOfSpeech.map { $0.0.lowercased() }//.filter { !stopwords.contains($0) }
        //logger.info(postprocess(keywords: topKeywords.map { $0.0 }, originalWords: temp))
    }
    
    func summarize(text: String, numberOfSentences: Int? = 10, biased: Bool = false) -> String {
        let body = SemanticSearch.shared.tokenize(text: text, unit: .sentence)
        let chunkSize = 5
        let chunks = stride(from: 0, to: body.count, by: chunkSize).map {
            Array(body[$0..<min($0 + chunkSize, body.count)])
        }
        var finalSummary = [String]()
        for chunk in chunks {
            let sentences = chunk
            let numberOfSentences = numberOfSentences != nil ? numberOfSentences! : 1/3 * sentences.count
            let graph = WeightedGraph<String, Double>()
            var addedVertices = [String : Int]()
            for w in Array(Set(sentences)) {
                let index = graph.addVertex(w)
                addedVertices[w] = index
            }
            for (i, v) in sentences.enumerated() {
                let vIndex = addedVertices[v]!
                for (j, w) in sentences.enumerated() {
                    if i == j {
                        continue
                    }
                    let wIndex = addedVertices[w]!
                    var weight: Double
                    if biased {
                        weight = 2.0 - SemanticSearch.shared.sentenceDistance(between: v, and: w)
                    }
                    else {
                        let vWords = SemanticSearch.shared.tokenize(text: v, unit: .word).map{ SemanticSearch.shared.lemmatize(text: $0.lowercased()) }
                        let wWords = SemanticSearch.shared.tokenize(text: w, unit: .word).map{ SemanticSearch.shared.lemmatize(text: $0.lowercased()) }
                        let commonWordsCount = Set(vWords).intersection(wWords).count
                        weight = Double(commonWordsCount) / Double((log(vWords.count)+log(wWords.count)))
                    }
                    if !graph.edgeExists(fromIndex: vIndex, toIndex: wIndex) && !graph.edgeExists(fromIndex: wIndex, toIndex: vIndex) {
                        if !biased || (biased && weight > 1.0) {
                            graph.addEdge(fromIndex: vIndex, toIndex: wIndex, weight: weight, directed: false)
                        }
                    }
                }
            }
            let scores = iterate(graph: graph)
            let topSentences = scores.sorted { x, y in
                x.1 > y.1
            }.slice(length: numberOfSentences)
            let summary = topSentences.map { $0.0 }.sorted { x, y in
                sentences.firstIndex(of: x)! < sentences.firstIndex(of: y)!
            }.joined(separator: " ")
            finalSummary.append(summary)
        }
        return finalSummary.joined(separator: " ")
    }
    
    // TextRank algorithm
    private func iterate(graph: WeightedGraph<String, Double>, convergenceThreshold: Double = 0.0001) -> [(String, Double)] {
        let d = 0.85
        var scores = [String : Double]()
        for v in graph {
            scores[v] = 1.0
        }
        var iteration = 0
        var convergence = false
        while !convergence && iteration < 30 {
            iteration += 1
            var newScores = scores
            for (i, v) in graph.enumerated() {
                var sum = 0.0
                let edges = graph.edgesForIndex(i)//.filter{$0.v == i} // In-links
                for edge in edges {
                    let otherVertexIndex = edge.u == i ? edge.v : edge.u
                    let otherVertex = graph.vertexAtIndex(otherVertexIndex)
                    let otherEdges = graph.edgesForIndex(otherVertexIndex)//.filter{$0.u == otherVertexIndex} // Out-links
                    if otherEdges.count > 0 {
                        let denominator = Double(otherEdges.map{ $0.weight }.reduce(0.0, +))
                        if denominator > 0.0 && edge.weight > 0.0 {
                            sum += (edge.weight / denominator) * newScores[otherVertex]!
                        }
                    }
                }
                newScores[v] = (1 - d) + d * sum
            }
            convergence = hasConverged(current: Array(scores.values), new: Array(newScores.values))
            scores = newScores
        }
        //logger.info("Iterations: \(iteration) | Convergence: \(convergence)")
        return scores.map { $0 }
    }
    
    private func hasConverged(current: [Double], new: [Double], threshold: Double = 0.0001) -> Bool {
        if current == new { return true }
        var total = 0.0
        for i in 0..<current.count {
            total += pow(new[i] - current[i], 2)
        }
        total = total/Double(current.count)
        return sqrt(total) < threshold
    }
    
    private func postprocess(keywords: [String], partsOfSpeech: [(String, String)]) -> [String] {
        var processedKeywords = keywords
        
        var combinations = [[String]]()
        var combination = [String]()
        var lastTag = ""
        for (token, tag) in partsOfSpeech {
            if combination.isEmpty {
                if tag == NLTag.adjective.rawValue || tag == NLTag.noun.rawValue {
                    combination.append(token)
                    lastTag = tag
                }
            }
            else {
                if combination.count == 1 {
                    if tag == NLTag.noun.rawValue || (tag == NLTag.adjective.rawValue && lastTag != NLTag.noun.rawValue) {
                        combination.append(token)
                        lastTag = tag
                    }
                    else {
                        combination.removeAll()
                        lastTag = ""
                    }
                }
                else { // 2
                    if tag == NLTag.noun.rawValue {
                        combination.append(token)
                        combinations.append(combination)
                        combination.removeAll()
                        lastTag = ""
                    }
                    else {
                        if lastTag == NLTag.noun.rawValue {
                            combinations.append(combination)
                        }
                        combination.removeAll()
                        lastTag = ""
                    }
                }
            }
        }
        
        for (i, v) in keywords.enumerated() {
            let combinations = combinations.filter{$0.contains(v)}
            var found = false
            if combinations.isEmpty {
                continue
            }
            for (j, w) in keywords.enumerated() {
                if i == j {
                    continue
                }
                let filteredCombinations = combinations.filter {$0.contains(w)}
                if filteredCombinations.isEmpty {
                    continue
                }
                else {
                    for c in filteredCombinations {
                        if c.count == 2 {
                            processedKeywords[i] = c.joined(separator: " ")
                            found = true
                            break
                        }
                        else {
                            for (k, x) in keywords.enumerated() {
                                if i == k || j == k {
                                    continue
                                }
                                let filteredCombinations = filteredCombinations.filter {$0.contains(x)}
                                if filteredCombinations.isEmpty {
                                    continue
                                }
                                else {
                                    processedKeywords[i] = filteredCombinations.first!.joined(separator: " ")
                                    found = true
                                    break
                                }
                            }
                        }
                        if found {
                            break
                        }
                    }
                }
            }
        }
        return processedKeywords
    }
    
    private func postprocess2(keywords: [String], originalWords: [String]) -> [String] {
        var processedKeywords = keywords
        
        for i in 0..<keywords.count {
            let v = keywords[i]
            if let originalIndex = originalWords.firstIndex(of: v) {
                for j in 0..<originalWords.count { // keywords
                    if i == j {
                        continue
                    }
                    let w = originalWords[j] // keywords
                    if w == "and" {
                        continue
                    }
                    if abs(originalIndex - j) == 1 {
                        if originalIndex - j > 0 {
                            processedKeywords[i] = w + " " + v
                            if w == "of" {
                                if j - 1 > 0 {
                                    processedKeywords[i] = originalWords[j - 1] + " " + processedKeywords[i]
                                }
                            }
                        }
                        else {
                            processedKeywords[i] = v + " " + w
                            if w == "of" {
                                if j + 1 < originalWords.count {
                                    processedKeywords[i] = processedKeywords[i] + " " + originalWords[j + 1]
                                }
                            }
                        }
                    }
                }
            }
        }
        return processedKeywords
    }
    
    private func postprocess3(keywords: [String], originalWords: [String]) -> [String] {
        var processedKeywords = keywords
        
        for i in 0..<keywords.count {
            let v = keywords[i]
            if let originalIndex = originalWords.firstIndex(of: v) {
                var count = 0
                for j in 0..<originalWords.count { // keywords
                    if i == j {
                        continue
                    }
                    let w = originalWords[j] // keywords
                    if w == "and" {
                        continue
                    }
                    if let otherOriginalIndex = originalWords.firstIndex(of: w) {
                        if abs(originalIndex - otherOriginalIndex) == 1 {
                            count += 1
                            if originalIndex - otherOriginalIndex > 0 {
                                processedKeywords[i] = w + " " + v
                                if w == "of" {
                                    if otherOriginalIndex - 1 > 0 {
                                        processedKeywords[i] = originalWords[otherOriginalIndex + 1] + " " + processedKeywords[i]
                                    }
                                }
                                
                                
                            }
                            else {
                                processedKeywords[i] = v + " " + w
                                if w == "of" {
                                    if otherOriginalIndex + 1 < originalWords.count {
                                        processedKeywords[i] = processedKeywords[i] + " " + originalWords[otherOriginalIndex - 1]
                                    }
                                }
                            }
                            //break
                        }
                    }
                    if count >= 2 {
                        break
                    }
                }
            }
            
        }
        return processedKeywords
    }
}

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
    
    func extractKeywords(text: String, numberOfKeywords: Int = 10) -> [String] {
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
                    graph.addEdge(fromIndex: index, toIndex: addedVertices[w]!, weight: 1.0, directed: false)
                }
            }
        }
        
        /*let N = 3 // Window size
        for (i, v) in graph.enumerated() {
            let minIndex = max(0, i-N)
            let maxIndex = min(graph.vertexCount, i+N)
            for w in graph[minIndex..<maxIndex] {
                if w != v {
                    graph.addEdge(from: v, to: w, weight: 1.0, directed: false)
                }
            }
        }*/
        /*let N = 3 // Window size
        for (i, v) in graph.enumerated() {
            let minIndex = max(0, i-N)
            let maxIndex = min(graph.vertexCount, i+N)
            for w in graph[minIndex..<maxIndex] {
                if w != v {
                    let weight = 2.0 - SemanticSearch.shared.wordDistance(between: v, and: w)
                    graph.addEdge(from: v, to: w, weight: weight, directed: false)
                }
            }
        }*/
        /*for v in graph {
            for w in graph {
                if v != w {
                    let weight = 2.0 - SemanticSearch.shared.wordDistance(between: v, and: w)
                    if weight > 1.0 {
                        graph.addEdge(from: v, to: w, weight: weight, directed: false)
                    }
                }
            }
        }*/
        
        let scores = executeAlgorithm(graph: graph)
        let topKeywords = scores.sorted { x, y in
            x.1 > y.1
        }.slice(length: numberOfKeywords)
        //let temp = partsOfSpeech.map { $0.0.lowercased() }//.filter { !stopwords.contains($0) }
        //logger.info(postprocess(keywords: topKeywords.map { $0.0 }, originalWords: temp))
        return topKeywords.map { $0.0 }
    }
    
    func summarize(text: String, numberOfSentences: Int? = 10) -> String {
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
                    let vWords = SemanticSearch.shared.tokenize(text: v, unit: .word).map{ SemanticSearch.shared.lemmatize(text: $0.lowercased()) }
                    let wWords = SemanticSearch.shared.tokenize(text: w, unit: .word).map{ SemanticSearch.shared.lemmatize(text: $0.lowercased()) }
                    let commonWordsCount = Set(vWords).intersection(wWords).count
                    let weight = Double(commonWordsCount) / Double((log(vWords.count)+log(wWords.count)))
                    // let weight = 2.0 - SemanticSearch.shared.sentenceDistance(between: v, and: w)
                    if !graph.edgeExists(fromIndex: vIndex, toIndex: wIndex) && !graph.edgeExists(fromIndex: wIndex, toIndex: vIndex){
                        graph.addEdge(fromIndex: vIndex, toIndex: wIndex, weight: weight, directed: false)
                    }
                }
            }
            let scores = executeAlgorithm(graph: graph)
            let topSentences = scores.sorted { x, y in
                x.1 > y.1
            }.slice(length: numberOfSentences)
            let summary = topSentences.map { $0.0 }.sorted { x, y in
                sentences.firstIndex(of: x)! < sentences.firstIndex(of: y)!
            }.joined(separator: " ")
            finalSummary.append(summary)
            //graph.mst()
        }
        return finalSummary.joined(separator: " ")
    }
    
    private func executeAlgorithm(graph: WeightedGraph<String, Double>, convergenceThreshold: Double = 0.0001) -> [(String, Double)] {
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
    
    private func postprocess(keywords: [String], originalWords: [String]) -> [String] {
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
    
    private func postprocess2(keywords: [String], originalWords: [String]) -> [String] {
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

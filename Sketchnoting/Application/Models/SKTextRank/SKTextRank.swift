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
        logger.info(topKeywords)
        logger.info(scores.filter{ $0.0 == "generic" || $0.0 == "generics"})
        return topKeywords.map { $0.0 }
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
                        sum += (edge.weight / Double(otherEdges.map{ $0.weight }.reduce(0.0, +))) * newScores[otherVertex]!
                    }
                }
                newScores[v] = (1 - d) + d * sum
            }
            convergence = hasConverged(current: Array(scores.values), new: Array(newScores.values))
            scores = newScores
        }
        logger.info("Iterations: \(iteration) | Convergence: \(convergence)")
        return scores.map { $0 }
    }
    
    private func hasConverged(current: [Double], new: [Double], threshold: Double = 0.0001) -> Bool {
        if current == new { return true }
        
        var total = 0.0
        for i in 0..<current.count {
            total += pow(new[i] - current[i], 2)
        }
        total = total/Double(current.count)
        logger.info(sqrt(total))
        return sqrt(total) < threshold
    }
    
    private func executeAlgorithm2(graph: WeightedGraph<String, Double>, convergenceThreshold: Double = 0.0001) -> [(String, Double)] {
        let d = 0.85
        var convergence = 1.0
        var scores = [String : Double]()
        for v in graph {
            scores[v] = 1.0
        }
        var iteration = 0
        while convergence > convergenceThreshold && iteration < 30 {
            iteration += 1
            var tempConvergence = 0.0
            for (i, v) in graph.enumerated() {
                var sum = 0.0
                let edges = graph.edgesForIndex(i).filter{$0.v == i} // In-links
                for edge in edges {
                    let otherVertexIndex = edge.u == i ? edge.v : edge.u
                    let otherVertex = graph.vertexAtIndex(otherVertexIndex)
                    let otherEdges = graph.edgesForIndex(otherVertexIndex).filter{$0.u == otherVertexIndex} // Out-links
                    if otherEdges.count > 0 {
                        sum += (edge.weight / Double(otherEdges.map{ $0.weight }.reduce(0.0, +))) * scores[otherVertex]!
                    }
                }
                let previousScore: Double = scores[v]!
                scores[v] = (1 - d) + d * sum
                tempConvergence = max(tempConvergence, abs(previousScore - scores[v]!))
            }
            convergence = tempConvergence
        }
        logger.info("Iterations: \(iteration+1) | Convergence: \(convergence)")
        return scores.map { $0 }
    }
}

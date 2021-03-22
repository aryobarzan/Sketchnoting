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
        let nounsAndAdjectives = Array(Set(partsOfSpeech.filter { $0.1 == NLTag.noun.rawValue || $0.1 == NLTag.adjective.rawValue || $0.1 == NLTag.other.rawValue }.map { SemanticSearch.shared.lemmatize(text: $0.0.lowercased()) })).filter { !stopwords.contains($0) }

        let graph: UnweightedGraph<String> = UnweightedGraph<String>()
        for word in nounsAndAdjectives {
            _ = graph.addVertex(word)
        }
        for v in graph {
            for w in graph {
                if v != w {
                    if SemanticSearch.shared.wordDistance(between: v, and: w) < 1.0 {
                        graph.addEdge(from: v, to: w, directed: false)
                    }
                }
            }
        }
        
        let scores = executeAlgorithm(graph: graph)
        let topKeywords = scores.sorted { x, y in
            x.1 > y.1
        }.slice(length: numberOfKeywords).map { $0.0 }
        
        return topKeywords
    }
    
    private func executeAlgorithm(graph: UnweightedGraph<String>, convergenceThreshold: Double = 0.0001) -> [(String, Double)] {
        let d = 0.85
        var convergence = 1.0
        var scores = [String : Double]()
        for v in graph {
            scores[v] = 1.0
        }
        var iteration = 0
        while convergence > convergenceThreshold && iteration < 30 {
            //logger.info("Convergence = \(convergence)")
            //logger.info("Iteration #\(iteration+1)")
            iteration += 1
            var tempConvergence = 0.0
            for (i, v) in graph.enumerated() {
                var sum = 0.0
                let edges = graph.edgesForIndex(i)
                for edge in edges {
                    let otherVertexIndex = edge.u == i ? edge.v : edge.u
                    let otherVertex = graph.vertexAtIndex(otherVertexIndex)
                    let otherEdges = graph.edgesForIndex(otherVertexIndex)
                    if otherEdges.count > 0 {
                        sum += (1.0 / Double(otherEdges.count)) * scores[otherVertex]!
                    }
                }
                let previousScore: Double = scores[v]!
                scores[v] = (1 - d) + d * sum
                tempConvergence = max(tempConvergence, abs(previousScore - scores[v]!))
            }
            convergence = tempConvergence
        }
        return scores.map { $0 }
    }
}

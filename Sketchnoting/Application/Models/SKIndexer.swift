//
//  SKIndexer.swift
//  Sketchnoting
//
//  Created by Aryobarzan on 18/02/2021.
//  Copyright © 2021 Aryobarzan. All rights reserved.
//

import Foundation
import NaturalLanguage

class SKIndexer {
    func index(note: Note) {
        let body = note.getText()
        let sentences = SemanticSearch.tokenize(text: body, unit: .sentence)
        var sentenceEmbeddings = [[Double]]()
        if let sentenceEmbedding = NLEmbedding.sentenceEmbedding(for: .english) {
            for sentence in sentences {
                if let vector = sentenceEmbedding.vector(for: sentence) {
                    sentenceEmbeddings.append(vector)
                    //log.info(vector)
                    let results = sentenceEmbedding.neighbors(for: vector, maximumCount: 1, distanceType: .cosine)
                    log.info(results[0].0)
                }
                else {
                    log.error("No vector representation possible for: \(sentence)")
                }
            }
        }
        
    }
    
    func remove(note: Note) {
        
    }
}

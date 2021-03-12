//
//  NoteSimilarity.swift
//  Sketchnoting
//
//  Created by Aryobarzan on 11/03/2021.
//  Copyright © 2021 Aryobarzan. All rights reserved.
//

import Foundation
import NaturalLanguage
import Accelerate

class NoteSimilarity {
    static var shared = NoteSimilarity()
    private init() {
        noteMatrices = [String : [[Double]]]()
    }
    var noteMatrices: [String : [[Double]]]
    
    func add(note: Note) {
        var matrix = [[Double]]()
        
        let titleTerms = SemanticSearch.shared.tokenize(text: note.getName(), unit: .word)
        let bodyTerms = SemanticSearch.shared.tokenize(text: note.getText(), unit: .word)
        // Convert to set to only retain unique terms
        var uniqueTerms = Array(Set(titleTerms + bodyTerms))
        var toRemove = [Int]()
        // Lemmatize & lowercase
        for i in 0..<uniqueTerms.count {
            let lemmatized = SemanticSearch.shared.lemmatize(text: uniqueTerms[i]).lowercased()
            if SemanticSearch.shared.getWordEmbedding().contains(lemmatized) {
                uniqueTerms[i] = lemmatized
            }
            else {
                uniqueTerms[i] = uniqueTerms[i].lowercased()
            }
            
            if stopwords.contains(uniqueTerms[i]) {
                toRemove.append(i)
            }
        }
        // Remove stop words
        uniqueTerms = uniqueTerms.enumerated().filter { !toRemove.contains($0.offset) }.map { $0.element }
        
        // Insert vector for each term to matrix
        if let wordEmbedding = NLEmbedding.wordEmbedding(for: .english) {
            for term in uniqueTerms {
                let vector = wordEmbedding.vector(for: term)
                if vector != nil {
                    matrix.append(vector!)
                }
                else {
                    logger.info("No vector for '\(term)'.")
                }
            }
        }
        
        noteMatrices[note.getID()] = matrix
    }
    
    func similarity(between note1: Note, and note2: Note) -> Double {
        let matrix1 = DMatrix(noteMatrices[note1.getID()]!)
        let matrix1_transposed = matrix1.transpose()
        let matrix2 = DMatrix(noteMatrices[note2.getID()]!)
        let matrix2_transposed = matrix2.transpose()
        
        let numerator = frobeniusNorm(matrix: replaceNegative(matrix: (matrix1_transposed ● matrix2).fast()))
        let denominator = sqrt(frobeniusNorm(matrix: replaceNegative(matrix: (matrix1_transposed ● matrix1).fast())) * frobeniusNorm(matrix: replaceNegative(matrix: (matrix2_transposed ● matrix2).fast())))
        return numerator / denominator
    }
    
    /*func transposed(matrix: [[Double]]) -> [[Double]] {
        guard let firstRow = matrix.first else { return [] }
        return firstRow.indices.map { index in
            matrix.map{ $0[index] }
        }
    }*/
    
    func frobeniusNorm(matrix: DMatrix) -> Double {
        var norm = 0.0
        for row in 0..<matrix.rows {
            for col in 0..<matrix.cols {
                let v = matrix[row, col]
                norm += pow(v, 2)
            }
        }
        return sqrt(norm)
    }
    
    func replaceNegative(matrix: DMatrix) -> DMatrix {
        var matrix = matrix
        for row in 0..<matrix.rows {
            for col in 0..<matrix.cols {
                let v = matrix[row, col]
                if v < 0 {
                    matrix[row, col] = max(0.0, v)
                }
            }
        }
        return matrix
    }
}

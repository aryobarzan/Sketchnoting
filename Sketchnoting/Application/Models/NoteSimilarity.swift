//
//  NoteSimilarity.swift
//  Sketchnoting
//
//  Created by Aryobarzan on 11/03/2021.
//  Copyright © 2021 Aryobarzan. All rights reserved.
//

import Foundation
import Accelerate
import NaturalLanguage

class NoteSimilarity {
    static var shared = NoteSimilarity()
    private init() {
        noteMatrices = [String : [[Double]]]()
    }
    var noteMatrices: [String : [[Double]]]
    
    func clear() {
        self.noteMatrices.removeAll()
    }
    
    func add(note: Note, uniqueOnly: Bool = false, useSentenceEmbedding: Bool = false, normalizeVector: Bool = false, parse: Bool = false, useKeywords: Bool = false, useDocuments: Bool = false, useNounsOnly: Bool = false, filterSentences: Bool = false) {
        var matrix = [[Double]]()
        
        if useSentenceEmbedding {
            let titleTerms = SemanticSearch.shared.tokenize(text: note.getName(), unit: .sentence)
            var bodySentences = SemanticSearch.shared.tokenize(text: note.getText(parse: parse), unit: .sentence)
            if filterSentences {
                bodySentences = bodySentences.filter {SemanticSearch.shared.checkPhraseType(queryPartsOfSpeech: SemanticSearch.shared.tag(text: $0, scheme: .lexicalClass)) == .Sentence}
            }
            // Convert to set to only retain unique terms
            var allSentences = (titleTerms + bodySentences).map { $0.lowercased() }
            if uniqueOnly {
                allSentences = Array(Set(allSentences))
            }
            // Insert vector for each sentence to matrix
            for sentence in allSentences {
                let vector = SemanticSearch.shared.getSentenceEmbedding().vector(for: sentence)
                if vector != nil {
                    matrix.append(normalizeVector ? normalize(vector!) : vector!)
                }
            }
        }
        else {
            let titleTerms = SemanticSearch.shared.tokenize(text: note.getName(), unit: .word)
            let noteText = note.getText(parse: parse)
            var bodyTerms = SemanticSearch.shared.tokenize(text: noteText, unit: .word)
            if bodyTerms.count > 10 && useKeywords {
                bodyTerms = Reductio.shared.keywords(from: noteText, count: 10)
                logger.info(bodyTerms.joined(separator: ", "))
            }
            else if useDocuments {
                bodyTerms = note.getDocuments().map { $0.title }
            }
            else if useNounsOnly {
                let taggedTerms = SemanticSearch.shared.tag(text: noteText, scheme: .lexicalClass)
                bodyTerms = taggedTerms.filter {$0.1 == NLTag.noun.rawValue }.map { $0.0 }
            }
            // Convert to set to only retain unique terms
            var allTerms = (titleTerms + bodyTerms).map { $0.lowercased() }
            if uniqueOnly {
                allTerms = Array(Set(allTerms))
            }
            
            var toRemove = [Int]()
            // Lemmatize
            for i in 0..<allTerms.count {
                let lemmatized = SemanticSearch.shared.lemmatize(text: allTerms[i])
                if SemanticSearch.shared.getWordEmbedding().contains(lemmatized) {
                    allTerms[i] = lemmatized
                }
                if stopwords.contains(allTerms[i]) {
                    toRemove.append(i)
                }
            }
            // Remove stop words
            allTerms = allTerms.enumerated().filter { !toRemove.contains($0.offset) }.map { $0.element }
            // Insert vector for each term to matrix
            for term in allTerms {
                let vector = SemanticSearch.shared.getWordEmbedding().vector(for: term)
                if vector != nil {
                    matrix.append(normalizeVector ? normalize(vector!) : vector!)
                }
            }
        }
        noteMatrices[note.getID()] = transpose(matrix: matrix)
    }
    
    private func normalize(_ vector: [Double]) -> [Double] {
        var norm = 0.0
        for value in vector {
            norm += pow(value, 2)
        }
        norm = sqrt(norm)
        return vector.map { $0 / norm }
    }
    
    private func similarity(between note1: Note, and note2: Note, norm: MatrixNorm = .Frobenius) -> Double {
        let numerator = compute(norm: norm, for: replaceNegative(multiply(noteMatrices[note1.getID()]!, noteMatrices[note2.getID()]!)))
        let denominator_1 = compute(norm: norm, for: replaceNegative(multiply(noteMatrices[note1.getID()]!, noteMatrices[note1.getID()]!)))
        let denominator_2 = compute(norm: norm, for: replaceNegative(multiply(noteMatrices[note2.getID()]!, noteMatrices[note2.getID()]!)))
        return numerator / (sqrt(denominator_1 * denominator_2))
        // Note: similarity value is only normalized to [0,1] range for Frobenius & L1,1 norms
    }
    
    // Baseline approach for comparing 2 notes
    func similarityAverage(matrix1: [[Double]], matrix2: [[Double]]) -> Double {
        var centroidVectors = [[Double]]()
        for matrix in [transpose(matrix: matrix1), transpose(matrix: matrix2)] {
            var centroid = [Double](repeating: 0.0, count: 300)
            var count = 0
            for vector in matrix {
                centroid = zip(centroid, vector).map(+)
                count += 1
            }
            centroid = centroid.map { $0 / Double(count) }
            centroidVectors.append(centroid)
        }
        return cosineDistance(vector1: centroidVectors[0], vector2: centroidVectors[1])
    }
    
    /** Dot Product **/
    private func dot(vector1: [Double], vector2: [Double]) -> Double {
        var x: Double = 0.0
        for i in 0..<vector1.count {
            x += vector1[i] * vector2[i]
        }
        return x
    }
    
    /** Vector Magnitude **/
    private func magnitude(vector: [Double]) -> Double {
        var x: Double = 0.0
        for element in vector {
            x += pow(element, 2)
        }
        return sqrt(x)
    }
    
    private func cosineDistance(vector1: [Double], vector2: [Double]) -> Double {
        return dot(vector1: vector1, vector2: vector2) / (magnitude(vector: vector1) * magnitude(vector: vector2))
    }
    
    private func multiply(_ matrix1: [[Double]], _ matrix2: [[Double]]) -> [Double] {
        let matrixA = transpose(matrix: matrix1)
        let matrixB = matrix2
       
        // Define matrix row and column sizes
        // Matrix A (transposed) has dimensions MxK
        // Matrix B has dimensions KxN
        let M = Int32(matrixA.count)
        let N = Int32(matrixB[0].count)
        let K = Int32(matrixA[0].count)
        rows = Int(M)
        columns = Int(N)
        
        // Resulting matrix has dimensions MxN
        var result: [Double] = [[Double]](repeating: [Double](repeating: 0, count: Int(N)), count: Int(M)).flatMap { $0 }
        
        // Accelerate only works on flat 1D arrays
        var matrixA_flat = matrixA.flatMap { $0 }
        var matrixB_flat = matrixB.flatMap { $0 }
        vDSP_mmulD(
            &matrixA_flat, vDSP_Stride(1),
            &matrixB_flat, vDSP_Stride(1),
            &result, vDSP_Stride(1),
            vDSP_Length(M),
            vDSP_Length(N),
            vDSP_Length(K)
        )
        return result
    }
    
    // Stored for later matrix norm computations
    private var columns: Int = 1
    private var rows: Int = 1
    
    func similarNotes(for source: Note, noteIterator: NoteIterator, maxResults: Int = 5) -> [((URL, Note), Double)] {
        var similarNotes = [((URL, Note), Double)]()
        if noteMatrices[source.getID()] == nil || noteMatrices[source.getID()]!.isEmpty {
            return [((URL, Note), Double)]()
        }
        var noteIterator = noteIterator
        while let note = noteIterator.next() {
            if note.1 == source || noteMatrices[note.1.getID()] == nil || noteMatrices[note.1.getID()]!.isEmpty {
                continue
            }
            let similarity = self.similarity(between: source, and: note.1)
            logger.info("Centroid Similarity '\(source.getName())' / '\(note.1.getName())': \(similarityAverage(matrix1: noteMatrices[source.getID()]!, matrix2: noteMatrices[note.1.getID()]!))")
            logger.info("Similarity '\(source.getName())' / '\(note.1.getName())': \(similarity)")
            if similarNotes.isEmpty {
                similarNotes.append((note, similarity))
            }
            else {
                var isInserted = false
                for i in 0..<similarNotes.count {
                    if similarity > similarNotes[i].1 {
                        similarNotes.insert((note, similarity), at: i)
                        isInserted = true
                        break
                    }
                }
                if !isInserted {
                    similarNotes.append((note, similarity))
                }
            }
        }
        let maxResults = max(1, maxResults)
        return Array(similarNotes.prefix(maxResults))
    }
    
    private func transpose(matrix: [[Double]]) -> [[Double]] {
        guard let firstRow = matrix.first else { return [] }
        return firstRow.indices.map { index in
            matrix.map{ $0[index] }
        }
    }
    
    /*private func transpose(matrix: [[Double]]) -> [[Double]] {
        let M = Int32(matrix.count)
        let N = Int32(matrix[0].count)
        
        // Transposed matrix has dimensions NxM
        var result: [Double] = [[Double]](repeating: [Double](repeating: 0, count: Int(M)), count: Int(N)).flatMap { $0 }
        var matrix_flat = matrix.flatMap { $0 }
        // Accelerate framework only works on flat (1D) arrays
        vDSP_mtransD(&matrix_flat, vDSP_Stride(1), &result, vDSP_Stride(1), vDSP_Length(N), vDSP_Length(M))
        // Transform transposed array to 2D matrix
        let matrix_2d_pattern = [[Double]](repeating: [Double](repeating: 0, count: Int(M)), count: Int(N))
        var iter = result.makeIterator()
        let matrix_2d = matrix_2d_pattern.map { $0.compactMap { _ in iter.next() } }
        return matrix_2d
    }*/
    
    private enum MatrixNorm {
        case Frobenius
        case L11Norm
        case OneNorm
        case InfinityNorm
    }
    
    private func compute(norm: MatrixNorm = .Frobenius, for matrix: [Double]) -> Double {
        switch norm {
        case .Frobenius:
            return computeFrobeniusNorm(matrix)
        case .L11Norm:
            return computeL11Norm(matrix)
        case .OneNorm:
            return compute1Norm(matrix)
        case .InfinityNorm:
            return computeInfinityNorm(matrix)
        }
    }
    
    private func computeFrobeniusNorm(_ matrix: [Double]) -> Double {
        var norm = 0.0
        for i in 0..<matrix.count {
            let v = matrix[i]
            norm += pow(v, 2)
        }
        return sqrt(norm)
    }
    
    private func computeL11Norm(_ matrix: [Double]) -> Double {
        var norm = 0.0
        for i in 0..<matrix.count {
            norm += abs(matrix[i])
        }
        return norm
    }
    
    private func compute1Norm(_ matrix: [Double]) -> Double {
        var max = 0.0
        let matrix_2d_pattern = [[Double]](repeating: [Double](repeating: 0, count: Int(columns)), count: Int(rows))
        var iter = matrix.makeIterator()
        let matrix_2d = matrix_2d_pattern.map { $0.compactMap { _ in iter.next() } }
        for column in 0..<columns {
            var sum = 0.0
            for row in 0..<rows {
                sum += abs(matrix_2d[row][column])
            }
            if sum > max {
                max = sum
            }
        }
        return max
    }
    
    private func computeInfinityNorm(_ matrix: [Double]) -> Double {
        var max = 0.0
        let matrix_2d_pattern = [[Double]](repeating: [Double](repeating: 0, count: Int(columns)), count: Int(rows))
        var iter = matrix.makeIterator()
        let matrix_2d = matrix_2d_pattern.map { $0.compactMap { _ in iter.next() } }
        for row in 0..<rows {
            var sum = 0.0
            for column in 0..<columns {
                sum += abs(matrix_2d[row][column])
            }
            if sum > max {
                max = sum
            }
        }
        return max
    }
    
    private func replaceNegative(_ matrix: [Double]) -> [Double] {
        var matrix = matrix
        for i in 0..<matrix.count {
            let v = matrix[i]
            if v < 0 {
                matrix[i] = max(0.0, v)
            }
        }
        return matrix
    }
}

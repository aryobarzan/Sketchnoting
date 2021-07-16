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

enum SimilarityMethod {
    case SemanticMatrix
    case SemanticCentroid
    case TFIDF
}

class NoteSimilarity {
    static var shared = NoteSimilarity()
    private init() {}
    
    func similarNotes(for source: Note, noteIterator: NoteIterator, maxResults: Int = 5, similarityMethod: SimilarityMethod = .SemanticCentroid) -> [((URL, Note), Double)] {
        switch similarityMethod {
        case .SemanticMatrix:
            return semanticMatrix_similarNotes(for: source, noteIterator: noteIterator, maxResults: maxResults)
        case .SemanticCentroid:
            return semanticCentroid_similarNotes(for: source, noteIterator: noteIterator, maxResults: maxResults)
        case .TFIDF:
            return TFIDF_similarNotesFor(for: source, noteIterator: noteIterator, maxResults: maxResults)
        }
    }
    // MARK: Semantic Matric method
    
    var noteMatrices = [String : [[Double]]]()
    
    func clear() {
        self.noteMatrices.removeAll()
    }
    
    func add2(note: Note) {
        var matrix = [[Double]]()
        let titleTerms = SemanticSearch.shared.tokenize(text: note.getName(), unit: .word)
        let noteText = SKTextRank.shared.summarize(text: note.getText(option: .FullText, parse: true), numberOfSentences: 1)
        var bodySentences = SemanticSearch.shared.tokenize(text: noteText, unit: .sentence)
        // Filter sentences
        bodySentences = bodySentences.filter {SemanticSearch.shared.checkPhraseType(queryPartsOfSpeech: SemanticSearch.shared.tag(text: $0, scheme: .lexicalClass)) == .Sentence}
        let bodyTerms = SemanticSearch.shared.tokenize(text: bodySentences.joined(separator: " "), unit: .word)
        // use Documents
        // bodyTerms = note.getDocuments().map { $0.title }
        // use nouns only
        // let taggedTerms = SemanticSearch.shared.tag(text: noteText, scheme: .lexicalClass)
        // bodyTerms = taggedTerms.filter {$0.1 == NLTag.noun }.map { $0.0 }
        
        // Convert to set to only retain unique terms
        let allTerms = (titleTerms + bodyTerms).map { $0.lowercased() }
        // unique only
        var uniqueTerms = [String]()
        for term in allTerms {
            if !uniqueTerms.contains(term) && !stopwords.contains(term) {
                uniqueTerms.append(SemanticSearch.shared.lemmatize(text: term))
            }
        }
        let wordEmbedding = SemanticSearch.shared.createWordEmbedding(type: .FastText)
        // Insert vector for each term to matrix
        for term in uniqueTerms {
            let vector = wordEmbedding.vector(for: term)
            if vector != nil {
                matrix.append(normalize(vector!))
            }
        }
        logger.info(matrix.count)
        noteMatrices[note.getID()] = transpose(matrix: matrix)
    }
    
    func add(note: Note) {
        var matrix = [[Double]]()
        let titleTerms = SemanticSearch.shared.tokenize(text: note.getName(), unit: .word)
        //let noteText = SKTextRank.shared.summarize(text: note.getText(option: .FullText, parse: true), numberOfSentences: 1)
        let noteText = note.getText(option: .FullText, parse: true)
        var bodySentences = SemanticSearch.shared.tokenize(text: noteText, unit: .sentence)
        // Filter sentences
        bodySentences = bodySentences.filter {SemanticSearch.shared.checkPhraseType(queryPartsOfSpeech: SemanticSearch.shared.tag(text: $0, scheme: .lexicalClass)) == .Sentence}
        var bodyTerms = SemanticSearch.shared.tokenize(text: bodySentences.joined(separator: " "), unit: .word)
        // use Documents
        // bodyTerms = note.getDocuments().map { $0.title }
        bodyTerms = SKTextRank.shared.extractKeywords(text: noteText, numberOfKeywords: 10, biased: false, usePostProcessing: false)
        // use nouns only
        // let taggedTerms = SemanticSearch.shared.tag(text: noteText, scheme: .lexicalClass)
        // bodyTerms = taggedTerms.filter {$0.1 == NLTag.noun }.map { $0.0 }
        
        // Convert to set to only retain unique terms
        let allTerms = (titleTerms + bodyTerms).map { $0.lowercased() }
        // unique only
        var uniqueTerms = [String]()
        for term in allTerms {
            if !uniqueTerms.contains(term) && !stopwords.contains(term) {
                uniqueTerms.append(SemanticSearch.shared.lemmatize(text: term))
            }
        }
        let wordEmbedding = SemanticSearch.shared.createWordEmbedding(type: .FastText)
        // Insert vector for each term to matrix
        for term in uniqueTerms {
            let vector = wordEmbedding.vector(for: term)
            if vector != nil {
                matrix.append(normalize(vector!))
            }
        }
        logger.info(matrix.count)
        noteMatrices[note.getID()] = transpose(matrix: matrix)
    }
    
    func remove(note: Note) {
        if noteMatrices[note.getID()] != nil {
            noteMatrices.removeValue(forKey: note.getID())
        }
    }
    
    private func normalize(_ vector: [Double]) -> [Double] {
        var norm = 0.0
        for value in vector {
            norm += pow(value, 2)
        }
        norm = sqrt(norm)
        return vector.map { $0 / norm }
    }
    
    // Matrix multiplication based approach
    private func similarity(between matrix1: [[Double]], and matrix2: [[Double]], norm: MatrixNorm = .Frobenius) -> Double {
        let numerator = compute(norm: norm, for: replaceNegative(multiply(matrix1, matrix2)))
        let denominator_1 = compute(norm: norm, for: replaceNegative(multiply(matrix1, matrix1)))
        let denominator_2 = compute(norm: norm, for: replaceNegative(multiply(matrix2, matrix2)))
        return numerator / (sqrt(denominator_1 * denominator_2))
        // Note: similarity value is only normalized to [0,1] range for Frobenius & L1,1 norms
    }
    private func similarity(between note1: Note, and note2: Note, norm: MatrixNorm = .Frobenius) -> Double {
        let numerator = compute(norm: norm, for: replaceNegative(multiply(noteMatrices[note1.getID()]!, noteMatrices[note2.getID()]!)))
        let denominator_1 = compute(norm: norm, for: replaceNegative(multiply(noteMatrices[note1.getID()]!, noteMatrices[note1.getID()]!)))
        let denominator_2 = compute(norm: norm, for: replaceNegative(multiply(noteMatrices[note2.getID()]!, noteMatrices[note2.getID()]!)))
        return numerator / (sqrt(denominator_1 * denominator_2))
        // Note: similarity value is only normalized to [0,1] range for Frobenius & L1,1 norms
    }
    
    // Baseline approach for comparing 2 notes
    private func similarityAverage(matrix1: [[Double]], matrix2: [[Double]]) -> Double {
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
    
    private func semanticMatrix_similarNotes(for source: Note, noteIterator: NoteIterator, maxResults: Int = 5, debug: Bool = false) -> [((URL, Note), Double)] {
        // Source note is either not indexed yet or has no text to be indexed
        if noteMatrices[source.getID()] == nil || noteMatrices[source.getID()]!.isEmpty {
            return [((URL, Note), Double)]()
        }
        
        var similarNotes = [((URL, Note), Double)]()
        
        var noteIterator = noteIterator
        while let note = noteIterator.next() {
            if note.1 == source || noteMatrices[note.1.getID()] == nil || noteMatrices[note.1.getID()]!.isEmpty {
                continue
            }
            let similarity = self.similarity(between: source, and: note.1)
            if debug {
                logger.info("TF-IDF Similarity '\(source.getName())' / '\(note.1.getName())': \(cosineDistance(vector1: getTFIDF(for: source), vector2: getTFIDF(for: note.1)))")
                logger.info("Centroid Similarity '\(source.getName())' / '\(note.1.getName())': \(similarityAverage(matrix1: noteMatrices[source.getID()]!, matrix2: noteMatrices[note.1.getID()]!))")
                logger.info("Similarity '\(source.getName())' / '\(note.1.getName())': \(similarity)")
                logger.info("----------")
            }
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
    
    // MARK: Semantic centroid technique
    private func semanticCentroid_similarNotes(for source: Note, noteIterator: NoteIterator, maxResults: Int = 5) -> [((URL, Note), Double)] {
        // Source note is either not indexed yet or has no text to be indexed
        if noteMatrices[source.getID()] == nil || noteMatrices[source.getID()]!.isEmpty {
            return [((URL, Note), Double)]()
        }
        
        var similarNotes = [((URL, Note), Double)]()
        
        var noteIterator = noteIterator
        while let note = noteIterator.next() {
            if note.1 == source || noteMatrices[note.1.getID()] == nil || noteMatrices[note.1.getID()]!.isEmpty {
                continue
            }
            let similarity = similarityAverage(matrix1: noteMatrices[source.getID()]!, matrix2: noteMatrices[note.1.getID()]!)
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
    
    // MARK: TF-IDF technique
    private var note_TFIDF = [String : [Double]]()
    
    func isTFIDFSetup() -> Bool {
        return !note_TFIDF.isEmpty
    }
    
    func setupTFIDF(noteIterator: NoteIterator) {
        var noteIterator = noteIterator
        
        note_TFIDF = [String : [Double]]()
        var noteBags = [String : [String]]()
        var noteTFs = [String : [String : Double]]()
        var wordIDFs = [String : Double]()
        var N = 0
        var uniqueWords = [String]()
        
        while let note = noteIterator.next() {
            N += 1
            // Lowercase, lemmatize & remove stopwords
            var words = SemanticSearch.shared.tokenize(text: note.1.getName(), unit: .word) +  SemanticSearch.shared.tokenize(text: note.1.getText(option: .FullText, parse: true), unit: .word)
            words = words.map { SemanticSearch.shared.lemmatize(text: $0.lowercased()) }
            words = words.filter { !stopwords.contains($0) }
            
            noteBags[note.1.getID()] = words
            uniqueWords += words
        }
        uniqueWords = Array(Set(uniqueWords))
        
        noteIterator.reset()
        
        while let note = noteIterator.next() {
            let noteBag = noteBags[note.1.getID()]!
            var counts = noteBag.reduce(into: [:]) { counts, word in counts[word, default: 0.0] += 1.0 }
            for (key, value) in counts {
                counts[key] = value / (Array(counts.values).reduce(0, +))
            }
            var dict = [String : Double]()
            for word in uniqueWords {
                if counts[word] == nil {
                    dict[word] = 0.0
                }
                else {
                    dict[word] = counts[word]
                }
            }
            noteTFs[note.1.getID()] = dict
        }
        
        for word in uniqueWords {
            var count: Double = 0.0
            for (_, value) in noteBags {
                if value.contains(word) {
                    count += 1.0
                }
            }
            wordIDFs[word] = Double(N) / (1 + count)
        }
        
        for (key, value) in noteTFs {
            var vector = [Double](repeating: 0.0, count: uniqueWords.count)
            for i in 0..<uniqueWords.count {
                vector[i] = value[uniqueWords[i]]! * wordIDFs[uniqueWords[i]]!
            }
            note_TFIDF[key] = vector
        }
    }
    
    func getTFIDF(for note: Note) -> [Double] {
        return note_TFIDF[note.getID()]!
    }
    
    private func TFIDF_similarNotesFor(for source: Note, noteIterator: NoteIterator, maxResults: Int = 5) -> [((URL, Note), Double)] {
        var similarNotes = [((URL, Note), Double)]()
        var noteIterator = noteIterator
        while let note = noteIterator.next() {
            if note.1 == source {
                continue
            }
            let similarity = cosineDistance(vector1: getTFIDF(for: source), vector2: getTFIDF(for: note.1))
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
}

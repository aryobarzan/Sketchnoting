//
//  SemanticSearch.swift
//  Sketchnoting
//
//  Created by Aryobarzan on 17/02/2021.
//  Copyright © 2021 Aryobarzan. All rights reserved.
//

import Foundation
import UIKit
import NaturalLanguage
import SwiftCoroutine
import CoreML

class SemanticSearch {
    
    public static let shared = SemanticSearch()
    private init() {
        //queue.maxConcurrentOperationCount = 1
        do {
            wordEmbedding = try NLEmbedding.init(contentsOf: Bundle.main.url(forResource: "FastTextWordEmbedding", withExtension: "mlmodelc")!)
        } catch {
            logger.error("Word embedding (FastText) could not be loaded - Falling back on built-in word embedding.")
            wordEmbedding = NLEmbedding.wordEmbedding(for: .english)!
        }
        sentenceEmbedding = NLEmbedding.sentenceEmbedding(for: .english)!
        
        locationSynonyms = ["location", "city", "place", "capital", "country", "county", "village"]
        personSynonyms = ["person"]
    }
    
    private let SEARCH_THRESHOLD = 0.5
    private let DRAWING_THRESHOLD = 0.5
    private let KEYWORD_THRESHOLD = 0.5
    private var locationSynonyms: [String]
    private var personSynonyms: [String]
    
    private var wordEmbedding: NLEmbedding = NLEmbedding.wordEmbedding(for: .english)!
    /*var wordEmbedding: NLEmbedding {
        get {
            return internalQueue.sync {
                    _wordEmbedding
            }
        }
        set (newValue) {
            internalQueue.async(flags: .barrier) {
                self._wordEmbedding = newValue
            }
        }
    }*/
    
    private let sentenceEmbedding: NLEmbedding
    
    //private let queue = OperationQueue()
    //private let internalQueue = DispatchQueue(label: "com.some.concurrentQueue", qos: .default, attributes: .concurrent)
    
    func tokenize(text: String, unit: NLTokenUnit = .sentence) -> [String] {
        let tokenizer = NLTokenizer(unit: unit)
        tokenizer.string = text
        let tokens = tokenizer.tokens(for: text.startIndex..<text.endIndex)
        var tokensAsString = [String]()
        for token in tokens {
            let tokenString = text[token]
            tokensAsString.append(String(tokenString))
        }
        return tokensAsString
    }
    
    func tag(text: String, scheme: NLTagScheme = .lexicalClass) -> [(String, String)] {
        let tagger = NLTagger(tagSchemes: [scheme])
        tagger.string = text
        let tags = tagger.tags(in: text.startIndex..<text.endIndex, unit: .word, scheme: scheme, options: [.omitPunctuation, .omitWhitespace, .joinNames, .joinContractions])
        var tagsTuple = [(String, String)]()
        for tag in tags {
            if let t = tag.0 {
                tagsTuple.append((String(text[tag.1]), t.rawValue))
            }
            else {
                tagsTuple.append((String(text[tag.1]), ""))
            }
        }
        return tagsTuple
    }
    
    func lemmatize(text: String) -> String {
        let tagger = NLTagger(tagSchemes: [.lemma])
        tagger.string = text
        let tags = tagger.tags(in: text.startIndex..<text.endIndex, unit: .word, scheme: .lemma, options: [.omitPunctuation, .omitWhitespace])
        var textLemmatized = text
        if tags.count > 0 && tags.first!.0 != nil {
            textLemmatized = tags[0].0!.rawValue
        }
        return textLemmatized
    }
    
    func neighbors(for word: String, maximumCount: Int = 5) -> [(String, Double)] {
        return wordEmbedding.neighbors(for: word, maximumCount: maximumCount)
    }
    
    func wordDistance(between word1: String, and word2: String) -> Double {
        return wordEmbedding.distance(between: word1, and: word2, distanceType: .cosine)
    }
    
    func sentenceDistance(between sentence1: String, and sentence2: String) -> Double {
        return sentenceEmbedding.distance(between: sentence1, and: sentence2, distanceType: .cosine)
    }
    
    func getWordEmbedding() -> NLEmbedding {
        return wordEmbedding
    }
    
    func getSentenceEmbedding() -> NLEmbedding {
        return sentenceEmbedding
    }
    
    func createFastTextWordEmbedding() -> NLEmbedding {
        if let resource = Bundle.main.url(forResource: "FastTextWordEmbedding", withExtension: "mlmodelc"), let embedding = try? NLEmbedding.init(contentsOf: resource) {
            return embedding
        }
        else {
            return NLEmbedding.wordEmbedding(for: .english)!
        }
    }
    
    //
    private func getTermRelevancy(for terms: [String]) -> [[String]] {
        let wordEmbedding = createFastTextWordEmbedding()
        // Pre-processing: lemmatize & lowercase the terms
        var terms = terms
        for i in 0..<terms.count {
            terms[i] = lemmatize(text: terms[i].lowercased())
        }
        // Clustering: separate the terms into semantically related groups/'clusters' which will form separate search queries
        var clusters = [[String]]()
        clusters.append([terms[0]])
        for term in terms[1..<terms.count] {
            var otherTerms = terms
            otherTerms.remove(object: term)
            var minimumDistance = 2.0
            //var highestCommonNotes = 0
            //let containingNotes = TF_IDF.shared.documentsForTerm(term: term, positiveOnly: true).compactMap({$0.noteID})
            var closestTerm = ""
            for otherTerm in otherTerms {
                let distance = wordEmbedding.distance(between: term, and: otherTerm)
                if distance < minimumDistance {
                    minimumDistance = distance
                    closestTerm = otherTerm
                }
               /* if distance >= 2.0 && !containingNotes.isEmpty {
                    let commonNotes = TF_IDF.shared.documentsForTerm(term: otherTerm, positiveOnly: true, documents: containingNotes)
                    let count = Int(commonNotes.count)
                    if count > highestCommonNotes {
                        highestCommonNotes = count
                        closestTerm = otherTerm
                    }
                }*/
                if closestTerm.isEmpty {
                    closestTerm = otherTerm
                }
            }
            var isAdded = false
            if minimumDistance < 1.0  { // || highestCommonNotes > 0
                for i in 0..<clusters.count {
                    if clusters[i].contains(closestTerm) {
                        clusters[i] = clusters[i] + [term]
                        isAdded = true
                        break
                    }
                }
            }
            if !isAdded {
                clusters.append([term])
            }
        }
        for cluster in clusters {
            logger.info("Cluster: \(cluster.joined(separator: " "))")
        }
        return clusters
    }
    
    private func preprocess(query: String, useFullQuery: Bool) -> [String] {
        let queryWords = tokenize(text: query, unit: .word)
        if queryWords.count > 1 { // Longer query
            var processedQuery = ""
            var allowed = [NLTag.noun.rawValue, NLTag.number.rawValue, NLTag.adjective.rawValue, NLTag.otherWord.rawValue]
            let partsOfSpeech = tag(text: queryWords.joined(separator: " "), scheme: .lexicalClass)
            var wordsDebug = ""
            var tagsDebug = ""
            for p in partsOfSpeech {
                wordsDebug.append(p.0 + " ")
                tagsDebug.append(p.1 + " ")
            }
            logger.info(wordsDebug)
            logger.info(tagsDebug)
            let phraseType = checkPhraseType(queryPartsOfSpeech: partsOfSpeech)
            if phraseType == .Sentence {
                let isQuestion = isSentenceQuestion(text: query)
                if !isQuestion {
                    allowed.append(NLTag.verb.rawValue)
                }
            }
            var retainedQueryTerms = [String]()
            for i in 0..<partsOfSpeech.count {
                if allowed.contains(partsOfSpeech[i].1) {
                    if partsOfSpeech[i].1 == NLTag.otherWord.rawValue {
                        if stopwords.contains(partsOfSpeech[i].0) {
                            continue
                        }
                    }
                    processedQuery.append("\(partsOfSpeech[i].0.lowercased()) ")
                    retainedQueryTerms.append(partsOfSpeech[i].0)
                }
            }
            if useFullQuery {
                return [retainedQueryTerms.joined(separator: " ").lowercased().trimmingCharacters(in: .whitespaces)]
            }
            else {
                let queryClusters = getTermRelevancy(for: retainedQueryTerms)
                var processedQueryClusters = [String]()
                for queryCluster in queryClusters {
                    processedQueryClusters.append(queryCluster.joined(separator: " ").lowercased().trimmingCharacters(in: .whitespaces))
                }
                return processedQueryClusters
            }
        }
        else if queryWords.count == 1 { // Keyword query
            return [lemmatize(text: queryWords[0].lowercased())]
        }
        return [queryWords.joined(separator: " ")]
    }
    
    public func search(query originalQuery: String, expandedSearch: Bool = true, useFullQuery: Bool = false) -> [SearchResult] {
        // Keyword, Clause, Extended Clause or Sentence
        let queries = preprocess(query: originalQuery, useFullQuery: useFullQuery)
        logger.info("----")
        logger.info("Original query: \(originalQuery)")
        if queries.count > 1 {
            logger.info("Query has been divided into \(Int(queries.count)) semantically different queries.")
        }
        // Expanded Search means a lower threshold for the lexical search, i.e. more tolerant to minor typos
        let lexicalThreshold = expandedSearch ? 0.9 : 1.0
        
        let wordEmbedding = createFastTextWordEmbedding()
        var noteIterator = NeoLibrary.getNoteIterator()
        var searchResults = [SearchResult]()
        for query in queries {
            noteIterator.reset()
            var searchResult = SearchResult(query: query)
            while let note = noteIterator.next() {
                var score_noteTitle = 0.0
                var score_noteText = 0.0
                var score_noteDrawings = 0.0
                var score_noteDocuments = 0.0
                // queue.addOperation
                var noteResult: (URL, Note)?
                // MARK: Note title
                let similarityResult = self.getStringSimilarity(betweenQuery: query, and: note.1.getName(), wordEmbedding: wordEmbedding)
                if similarityResult.lexicalSimilarity >= lexicalThreshold || similarityResult.semanticSimilarity >= self.SEARCH_THRESHOLD {
                    noteResult = note
                    score_noteTitle = similarityResult.getHighestSimilarity()
                    //logger.info("[Lexical] Note title ('\(closestTarget)') = \(score)")
                }
                // MARK: Note body (handwritten + PDF text)
                let noteText = note.1.getText(option: .FullText, parse: false)
                if !noteText.isEmpty {
                    let similarityResult = self.getStringSimilarity(betweenQuery: query, and: noteText, wordEmbedding: wordEmbedding)
                    if similarityResult.lexicalSimilarity >= lexicalThreshold || similarityResult.semanticSimilarity >= self.SEARCH_THRESHOLD {
                        noteResult = note
                        score_noteText = similarityResult.getHighestSimilarity()
                        //logger.info("[Semantic] Note body ('\(closestTarget)') = \(score)")
                    }
                }
                // MARK: Note recognized drawings
                let noteDrawingLabels = note.1.getDrawingLabels()
                if !noteDrawingLabels.isEmpty {
                    let similarityResult = self.getStringSimilarity(betweenQuery: query, and: note.1.getDrawingLabels().joined(separator: " "), wordEmbedding: wordEmbedding)
                    if similarityResult.lexicalSimilarity >= lexicalThreshold || similarityResult.semanticSimilarity >= self.DRAWING_THRESHOLD {
                        noteResult = note
                        score_noteDrawings = similarityResult.getHighestSimilarity()
                        //logger.info("[Semantic] Note drawing ('\(closestTarget)') = \(score)")
                    }
                }
                // MARK: Documents
                var highestSemanticSimilarity = 0.0
                var highestLexicalSimilarity = 0.0
                for document in note.1.getDocuments(includeHidden: false) {
                    var isDocumentMatching = false
                    var score_documentTitle = 0.0
                    var score_documentDescription = 0.0
                    // Document title
                    let similarityResult = self.getStringSimilarity(betweenQuery: query, and: document.title, wordEmbedding: wordEmbedding)
                    if similarityResult.lexicalSimilarity >= lexicalThreshold || similarityResult.semanticSimilarity >= self.SEARCH_THRESHOLD {
                        noteResult = note
                        isDocumentMatching = true
                        score_documentTitle = similarityResult.getHighestSimilarity()
                        //logger.info("[Semantic] Document ('\(document.title)') title ('\(closestTarget)') = \(score)")
                    }
                    highestSemanticSimilarity = max(highestSemanticSimilarity, similarityResult.semanticSimilarity)
                    highestLexicalSimilarity = max(highestLexicalSimilarity, similarityResult.lexicalSimilarity)
                    // Document description (abstract)
                    if let description = document.getDescription() {
                        let similarityResult = self.getStringSimilarity(betweenQuery: query, and: description, wordEmbedding: wordEmbedding)
                        if similarityResult.lexicalSimilarity >= lexicalThreshold || similarityResult.semanticSimilarity >= self.SEARCH_THRESHOLD {
                            noteResult = note
                            isDocumentMatching = true
                            score_documentDescription = similarityResult.getHighestSimilarity()
                            //logger.info("[Semantic] Document ('\(document.title)') description ('\(closestTarget)') = \(score)")
                        }
                        highestSemanticSimilarity = max(highestSemanticSimilarity, similarityResult.semanticSimilarity)
                        highestLexicalSimilarity = max(highestLexicalSimilarity, similarityResult.lexicalSimilarity)
                    }
                    if isDocumentMatching {
                        let documentScore = score_documentTitle + score_documentDescription
                        searchResult.documents.append((document, documentScore))
                        logger.info("Document \(document.title) score = \(documentScore)")
                    }
                    // Document types [TODO]
                }
                let highestDocumentSimilarity = max(highestSemanticSimilarity, highestLexicalSimilarity)
                if highestDocumentSimilarity > self.SEARCH_THRESHOLD {
                    score_noteDocuments = highestDocumentSimilarity
                    
                }
                if let noteResult = noteResult {
                    if searchResult.notes[noteResult.0] == nil {
                        let score = 2 * score_noteTitle + 2 * score_noteText + 2 * score_noteDrawings + score_noteDocuments
                        logger.info("Search score for note '\(note.1.getName())' = \(score)")
                        searchResult.notes[noteResult.0] = (noteResult.1, score)
                    }
                }
            }
            searchResults.append(searchResult)
        }
        logger.info("Search for query '\(originalQuery)' completed.")
        return searchResults
    }
    
    private enum SearchType: String {
        case Lexical
        case Semantic
    }

    private func getStringSimilarity(betweenQuery query: String, and target: String, wordEmbedding: NLEmbedding) -> StringSimilarityResult {
        let target = target.trimmingCharacters(in: .whitespacesAndNewlines)
        let targetSentences = tokenize(text: target, unit: .sentence)
        let targetWords = tokenize(text: target, unit: .word)
        let queryWords = tokenize(text: query, unit: .word)
        
        let partsOfSpeech = tag(text: query, scheme: .lexicalClass)
        let queryPhraseType = checkPhraseType(queryPartsOfSpeech: partsOfSpeech)
        
        if queryPhraseType == .Clause || queryPhraseType == .ExtendedClause {
            var semanticSimilarities = [Double]()
            var lexicalSimilarities = [Double]()
            var closestSemanticTarget: String = ""
            var closestLexicalTarget: String = ""
            for queryWord in queryWords {
                var highestSemanticSimilarity = 0.0 // Higher is better - Semantic distance
                var highestLexicalSimilarity = 0.0 // Higher is better - Damerau-Levenshtein ratio
                var temp_closestSemanticTarget = ""
                var temp_closestLexicalTarget = ""
                for word in targetWords {
                    let word = word.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                    let semanticSimilarity = (2.0 - wordEmbedding.distance(between: queryWord, and: word)) / 2.0
                    if semanticSimilarity > highestSemanticSimilarity {
                        highestSemanticSimilarity = semanticSimilarity
                        temp_closestSemanticTarget = word
                    }
                    let levenshteinDistance = queryWord.distance(between: word, metric: .DamerauLevenshtein)
                    let lengthsSum = Double(query.count + word.count)
                    let levenshteinRatio: Double = (lengthsSum - Double(levenshteinDistance))/lengthsSum
                    if levenshteinRatio > highestLexicalSimilarity {
                        highestLexicalSimilarity = levenshteinRatio
                        temp_closestLexicalTarget = word
                    }
                }
                semanticSimilarities.append(highestSemanticSimilarity)
                lexicalSimilarities.append(highestLexicalSimilarity)
                closestSemanticTarget += temp_closestSemanticTarget
                closestLexicalTarget += temp_closestLexicalTarget
            }
            var semanticSimilarity = 0.0
            if !semanticSimilarities.isEmpty {
                semanticSimilarity = Double(semanticSimilarities.reduce(0.0, +)) / Double(semanticSimilarities.count)
            }
            var lexicalSimilarity = 0.0
            if !lexicalSimilarities.isEmpty {
                lexicalSimilarity = Double(lexicalSimilarities.reduce(0.0, +)) / Double(lexicalSimilarities.count)
            }
            let result = StringSimilarityResult(closestSemanticTarget, closestLexicalTarget, semanticSimilarity, lexicalSimilarity)
            return result
        }
        else {
            var highestSemanticSimilarity = 0.0 // Higher is better - Semantic distance
            var highestLexicalSimilarity = 0.0 // Higher is better - Damerau-Levenshtein ratio
            var closestSemanticTarget = ""
            var closestLexicalTarget = ""
            for sentence in targetSentences {
                let sentence = sentence.trimmingCharacters(in: .whitespaces)
                let targetWords = tokenize(text: sentence, unit: .word)
                var semanticSimilarity = 0.0
                if queryWords.count > 1 {
                    semanticSimilarity = (2.0 - sentenceEmbedding.distance(between: query, and: sentence)) / 2.0
                    if semanticSimilarity > highestSemanticSimilarity {
                        highestSemanticSimilarity = semanticSimilarity
                        closestSemanticTarget = sentence
                    }
                    // Lexical
                    let levenshteinDistance = query.lowercased().distance(between: sentence.lowercased(), metric: .DamerauLevenshtein)
                    let lengthsSum = Double(query.count + sentence.count)
                    let lexicalSimilarity: Double = (lengthsSum - Double(levenshteinDistance))/lengthsSum
                    if lexicalSimilarity > highestLexicalSimilarity {
                        highestLexicalSimilarity = lexicalSimilarity
                        closestLexicalTarget = sentence
                    }
                }
                else {
                    for word in targetWords {
                        let word = word.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                        semanticSimilarity = (2.0 - wordEmbedding.distance(between: query, and: word)) / 2.0
                        if semanticSimilarity > highestSemanticSimilarity {
                            highestSemanticSimilarity = semanticSimilarity
                            closestSemanticTarget = sentence
                        }
                        let levenshteinDistance = query.lowercased().distance(between: word, metric: .DamerauLevenshtein)
                        let lengthsSum = Double(query.count + word.count)
                        let lexicalSimilarity: Double = (lengthsSum - Double(levenshteinDistance))/lengthsSum
                        if lexicalSimilarity > highestLexicalSimilarity {
                            highestLexicalSimilarity = lexicalSimilarity
                            closestLexicalTarget = sentence
                        }
                    }
                }
            }
            let result = StringSimilarityResult(closestSemanticTarget, closestLexicalTarget, highestSemanticSimilarity, highestLexicalSimilarity)
            return result
        }
    }
    
    enum PhraseType: String {
        case Keyword = "Keyword"
        case Clause = "Clause"
        case ExtendedClause = "Extended Clause"
        case Sentence = "Sentence"
    }
    
    func checkPhraseType(queryPartsOfSpeech: [(String, String)]) -> PhraseType {
        if queryPartsOfSpeech.count == 1 {
            return PhraseType.Keyword
        }
        var hasSubject = false
        var hasVerb = false
        for tag in queryPartsOfSpeech {
            if tag.1 == NLTag.noun.rawValue {
                hasSubject = true
            }
            else if tag.1 == NLTag.verb.rawValue {
                hasVerb = true
            }
            if hasSubject && hasVerb {
                return PhraseType.Sentence
            }
        }
        if queryPartsOfSpeech.count >= 5 {
            return PhraseType.ExtendedClause
        }
        else {
            return PhraseType.Clause
        }
    }
    
    func isSentenceQuestion(text: String) -> Bool {
        let questionKeywords = ["who", "what", "where", "which", "when", "whose"]
        let words = tokenize(text: text, unit: .word)
        for word in words {
            let word = lemmatize(text: word).lowercased()
            if questionKeywords.contains(word) {
                return true
            }
        }
        if text.hasSuffix("?") {
            return true
        }
        return false
    }
}

struct SearchResult {
    typealias Score = Double
    var query: String
    var notes = [URL : (Note, Score)]()
    var documents = [(Document, Score)]()
}

struct StringSimilarityResult {
    var closestSemanticTarget: String
    var closestLexicalTarget: String
    var semanticSimilarity: Double
    var lexicalSimilarity: Double
    
    init(_ closestSemanticTarget: String, _ closestLexicalTarget: String, _ semanticSimilarity: Double, _ lexicalSimilarity: Double) {
        self.closestSemanticTarget = closestSemanticTarget
        self.closestLexicalTarget = closestLexicalTarget
        self.semanticSimilarity = semanticSimilarity
        self.lexicalSimilarity = lexicalSimilarity
    }
    
    func getHighestSimilarity() -> Double {
        return max(semanticSimilarity, lexicalSimilarity)
    }
}

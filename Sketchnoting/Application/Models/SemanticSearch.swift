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
    
    private let SEARCH_THRESHOLD = 0.8
    private let DRAWING_THRESHOLD = 0.7
    private let KEYWORD_THRESHOLD = 0.6
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
    
    private func process(query: String) -> [String] {
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
            let queryClusters = getTermRelevancy(for: retainedQueryTerms)
            var processedQueryClusters = [String]()
            for queryCluster in queryClusters {
                processedQueryClusters.append(queryCluster.joined(separator: " ").lowercased().trimmingCharacters(in: .whitespaces))
            }
            return processedQueryClusters
        }
        else if queryWords.count == 1 { // Keyword query
            return [lemmatize(text: queryWords[0].lowercased())]
        }
        return [queryWords.joined(separator: " ")]
    }
    
    public func search(query originalQuery: String, expandedSearch: Bool = true) -> [SearchResult] {
        // Keyword, Clause, Extended Clause or Sentence
        //let queryType = checkPhraseType(queryPartsOfSpeech: queryPartsOfSpeech)
        let queries = process(query: originalQuery)
        logger.info("----")
        logger.info("Original query: \(originalQuery)")
        logger.info("Query has been divided into \(Int(queries.count)) semantically different queries.")
        // Expanded Search means a lower threshold for the lexical search, i.e. more tolerant to minor typos
        let lexicalThreshold = expandedSearch ? 0.9 : 1.0
        
        // Start search process, going through each note
        var noteIterator = NeoLibrary.getNoteIterator()
        var searchResults = [SearchResult]()
        let wordEmbedding = createFastTextWordEmbedding()
        for query in queries {
            noteIterator.reset()
            var searchResult = SearchResult(query: query)
            while let note = noteIterator.next() {
                var scores = [Double]()
                // queue.addOperation
                var noteResult: (URL, Note)?
                // MARK: Note title
                var (searchType, closestTarget, score) = self.getStringSimilarity(betweenQuery: query, and: note.1.getName(), wordEmbedding: wordEmbedding)
                switch searchType {
                case .Lexical:
                    if score >= lexicalThreshold { // Higher is better
                        noteResult = note
                        logger.info("[Lexical] Note title ('\(closestTarget)') = \(score)")
                        break
                    }
                case .Semantic:
                    if score <= self.SEARCH_THRESHOLD { // Lower is better
                        noteResult = note
                        scores.append(2.0 - score)
                        logger.info("[Semantic] Note title ('\(closestTarget)') = \(score)")
                        break
                    }
                }
                // MARK: Note body (handwritten + PDF text)
                let noteText = note.1.getText(option: .FullText, parse: false).trimmingCharacters(in: .whitespacesAndNewlines)
                if !noteText.isEmpty {
                    (searchType, closestTarget, score) = self.getStringSimilarity(betweenQuery: query, and: noteText, wordEmbedding: wordEmbedding)
                    switch searchType {
                    case .Lexical:
                        if score >= lexicalThreshold { // Higher is better
                            noteResult = note
                            logger.info("[Lexical] Note body ('\(closestTarget)') = \(score)")
                            break
                        }
                    case .Semantic:
                        if score <= self.SEARCH_THRESHOLD { // Lower is better
                            noteResult = note
                            scores.append(2.0 - score)
                            logger.info("[Semantic] Note body ('\(closestTarget)') = \(score)")
                            break
                        }
                    }
                }
                // MARK: Note recognized drawings
                let noteDrawingLabels = note.1.getDrawingLabels()
                if !noteDrawingLabels.isEmpty {
                    (searchType, closestTarget, score) = self.getStringSimilarity(betweenQuery: query, and: note.1.getDrawingLabels(), wordEmbedding: wordEmbedding)
                    switch searchType {
                    case .Lexical:
                        if score >= lexicalThreshold { // Higher is better
                            noteResult = note
                            logger.info("[Lexical] Note drawing ('\(closestTarget)') = \(score)")
                            break
                        }
                    case .Semantic:
                        if score <= self.DRAWING_THRESHOLD { // Lower is better
                            noteResult = note
                            logger.info("[Semantic] Note drawing ('\(closestTarget)') = \(score)")
                            break
                        }
                    }
                }
                // MARK: Documents
                var lowestDistance = 2.0
                for document in note.1.getDocuments(includeHidden: false) {
                    var isDocumentMatching = false
                    // Document title
                    (searchType, closestTarget, score) = self.getStringSimilarity(betweenQuery: query, and: document.title, wordEmbedding: wordEmbedding)
                    switch searchType {
                    case .Lexical:
                        if score >= lexicalThreshold { // Higher is better
                            noteResult = note
                            isDocumentMatching = true
                            logger.info("[Lexical] Document ('\(document.title)') title ('\(closestTarget)') = \(score)")
                            break
                        }
                    case .Semantic:
                        if score <= self.SEARCH_THRESHOLD { // Lower is better
                            noteResult = note
                            if score < lowestDistance {
                                lowestDistance = score
                            }
                            isDocumentMatching = true
                            logger.info("[Semantic] Document ('\(document.title)') title ('\(closestTarget)') = \(score)")
                            break
                        }
                    }
                    if isDocumentMatching {
                        searchResult.documents.append(document)
                        continue
                    }
                    // Document description (abstract)
                    if let description = document.getDescription() {
                        (searchType, closestTarget, score) = self.getStringSimilarity(betweenQuery: query, and: description, wordEmbedding: wordEmbedding)
                        switch searchType {
                        case .Lexical:
                            if score >= lexicalThreshold { // Higher is better
                                noteResult = note
                                isDocumentMatching = true
                                logger.info("[Lexical] Document ('\(document.title)') description ('\(closestTarget)') = \(score)")
                                break
                            }
                        case .Semantic:
                            if score <= self.SEARCH_THRESHOLD { // Lower is better
                                noteResult = note
                                if score < lowestDistance {
                                    lowestDistance = score
                                }
                                isDocumentMatching = true
                                logger.info("[Semantic] Document ('\(document.title)') description ('\(closestTarget)') = \(score)")
                                break
                            }
                        }
                    }
                    if isDocumentMatching {
                        searchResult.documents.append(document)
                        continue
                    }
                    // Document types [TODO]
                }
                if lowestDistance != 2.0 {
                    scores.append(2.0 - lowestDistance)
                }
                
                if let noteResult = noteResult {
                    if searchResult.notes[noteResult.0] == nil {
                        var finalScore = 0.0
                        if !scores.isEmpty {
                            finalScore = (Double(scores.reduce(0.0, +))/Double(scores.count)) / 2.0
                            logger.info("\(finalScore)")
                        }
                        searchResult.notes[noteResult.0] = (noteResult.1, finalScore)
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
    
    // Helper function for list of words
    private func getStringSimilarity(betweenQuery query: String, and target: [String], wordEmbedding: NLEmbedding) -> (SearchType, String, Double) {
        var (searchType, closestTarget, score) = (SearchType.Lexical, "", -1.0)
        for word in target {
            if score == -1.0 {
                (searchType, closestTarget, score) = getStringSimilarity(betweenQuery: query, and: word, wordEmbedding: wordEmbedding)
            }
            else {
                let temp = getStringSimilarity(betweenQuery: query, and: word, wordEmbedding: wordEmbedding)
                if temp.0 == .Lexical {
                    if temp.2 > score { // Higher is better
                        (searchType, closestTarget, score) = temp
                    }
                }
                else if temp.0 == .Semantic {
                    if temp.2 < score { // Lower is better
                        (searchType, closestTarget, score) = temp
                    }
                }
            }
        }
        return (searchType, closestTarget, score)
    }
    
    private func getStringSimilarity(betweenQuery query: String, and target: String, wordEmbedding: NLEmbedding) -> (SearchType, String, Double) {
        let target = target.trimmingCharacters(in: .whitespaces)
        let sentences = tokenize(text: target, unit: .sentence)
        let queryWords = tokenize(text: query, unit: .word)
        
        var minimumSemanticDistance = 2.0 // Lower is better
        var highestLevenshteinRatio = 0.0 // Higher is better
        var closestTarget = ""
        for sentence in sentences {
            let sentence = sentence.trimmingCharacters(in: .whitespaces)
            let targetWords = tokenize(text: sentence, unit: .word)
            var semanticDistance = 2.0
            if queryWords.count > 1 {
                semanticDistance = sentenceEmbedding.distance(between: query, and: sentence, distanceType: .cosine)
                if semanticDistance < minimumSemanticDistance {
                    minimumSemanticDistance = semanticDistance
                    closestTarget = sentence
                }
                if semanticDistance >= 2.0 { // Meaning: sentence is unknown to sentence embedder (has no vector representation)
                    // Lexical
                    let levenshteinDistance = query.lowercased().distance(between: sentence.lowercased(), metric: .DamerauLevenshtein)
                    let lengthsSum = Double(query.count + sentence.count)
                    let temp: Double = (lengthsSum - Double(levenshteinDistance))/lengthsSum
                    if temp > highestLevenshteinRatio {
                        highestLevenshteinRatio = temp
                        closestTarget = sentence
                    }
                }
            }
            else {
                for word in targetWords {
                    let word = word.trimmingCharacters(in: .whitespaces).lowercased()
                    semanticDistance = wordEmbedding.distance(between: query, and: word)
                    if semanticDistance < minimumSemanticDistance {
                        minimumSemanticDistance = semanticDistance
                        closestTarget = sentence
                    }
                    if semanticDistance >= 2.0 {
                        let levenshteinDistance = query.lowercased().distance(between: word, metric: .DamerauLevenshtein)
                        let lengthsSum = Double(query.count + word.count)
                        let temp: Double = (lengthsSum - Double(levenshteinDistance))/lengthsSum
                        if temp > highestLevenshteinRatio {
                            highestLevenshteinRatio = temp
                            closestTarget = sentence
                        }
                    }
                }
            }
        }
        if minimumSemanticDistance >= 2.0 {
            return (SearchType.Lexical, closestTarget, highestLevenshteinRatio)
        }
        else {
            return (SearchType.Semantic, closestTarget, minimumSemanticDistance)
        }
    }
    //
    
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
    var query: String
    var notes = [URL : (Note, Double)]()
    var documents = [Document]()
    var locationDocuments = [Document]()
    var personDocuments = [Document]()
    
    var bodyScore: Double = 0.0
    var drawingScore: Double = 0.0
    var documentScore: Double = 0.0
}

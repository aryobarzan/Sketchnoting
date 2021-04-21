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
    
    private func preprocess(query: String, useFullQuery: Bool) -> ([String], Bool) {
        var useFullQuery = useFullQuery
        let queryWords = tokenize(text: query, unit: .word)
        if queryWords.count > 1 { // Longer query
            var processedQuery = ""
            var allowed = [NLTag.noun.rawValue, NLTag.adjective.rawValue, NLTag.otherWord.rawValue]
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
            var isQuestion = false
            if phraseType == .Sentence {
                isQuestion = isQueryQuestion(text: query)
                if !isQuestion {
                    allowed.append(NLTag.verb.rawValue)
                }
                else {
                    useFullQuery = true
                }
            }
            var retainedQueryTerms = [String]()
            // MARK: TODO - more improvements needed
            if partsOfSpeech.filter({$0.1 != NLTag.otherWord.rawValue}).isEmpty || useFullQuery {
                retainedQueryTerms = partsOfSpeech.map{$0.0.lowercased()}.filter{!stopwords.contains($0)}
                useFullQuery = true
                isQuestion = isQueryQuestion(text: query)
            }
            else {
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
            }
            if useFullQuery {
                return ([Array(Set(retainedQueryTerms)).joined(separator: " ").lowercased().trimmingCharacters(in: .whitespaces)], isQuestion)
            }
            else {
                let queryClusters = getTermRelevancy(for: retainedQueryTerms)
                var processedQueryClusters = [String]()
                for queryCluster in queryClusters {
                    processedQueryClusters.append(Array(Set(queryCluster)).joined(separator: " ").lowercased().trimmingCharacters(in: .whitespaces))
                }
                return (processedQueryClusters, isQuestion)
            }
        }
        else if queryWords.count == 1 { // Keyword query
            return ([lemmatize(text: queryWords[0].lowercased())], false)
        }
        return ([queryWords.joined(separator: " ")], false)
    }
    
    public func search(query originalQuery: String, expandedSearch: Bool = true, filterQuality: Bool = true, useFullQuery: Bool = false, resultHandler: (SearchResult) -> Void, subqueriesHandler: ([String]) -> Void, searchFinishHandler: () -> Void) {
        // Keyword, Clause, Extended Clause or Sentence
        let (queries, isQuestion) = preprocess(query: originalQuery, useFullQuery: useFullQuery)
        logger.info("----")
        logger.info("Original query: \(originalQuery)")
        if queries.count > 1 {
            logger.info("Query has been divided into \(Int(queries.count)) semantically different queries.")
            subqueriesHandler(queries)
        }
        // Expanded Search means a lower threshold for the lexical search, i.e. more tolerant to minor typos
        let lexicalThreshold = expandedSearch ? 0.9 : 1.0
        let bert = BERT()
        let wordEmbedding = createFastTextWordEmbedding()
        var noteIterator = NeoLibrary.getNoteIterator()
        for query in queries {
            noteIterator.reset()
            var searchResult = SearchResult(query: query)
            while let note = noteIterator.next() {
                var score_noteTitle = 0.0
                var score_noteText = 0.0
                var score_noteDrawings = 0.0
                var score_noteDocuments = 0.0
                var noteResult: (URL, Note)?
                var searchNoteResult: SearchNoteResult?
                // MARK: Note title
                let similarityResult = self.getStringSimilarity(betweenQuery: query, and: note.1.getName(), wordEmbedding: wordEmbedding)
                if similarityResult.lexicalSimilarity >= lexicalThreshold || similarityResult.semanticSimilarity >= self.SEARCH_THRESHOLD {
                    noteResult = note
                    score_noteTitle = similarityResult.getHighestSimilarity()
                    //logger.info("[Lexical] Note title ('\(closestTarget)') = \(score)")
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
                // MARK: Note body
                var pageResults = [(PageIndex, PageHit, PageHitContext, PageHitSimilarity)]()
                for (pageIndex, page) in note.1.pages.enumerated() {
                    let pageText = page.getText(option: .FullText, parse: false)
                    if !pageText.isEmpty {
                        let paragraphs = tokenize(text: pageText, unit: .paragraph)
                        for paragraph in paragraphs {
                            let similarityResult = self.getStringSimilarity(betweenQuery: query, and: paragraph, wordEmbedding: wordEmbedding)
                            if similarityResult.lexicalSimilarity >= lexicalThreshold || similarityResult.semanticSimilarity >= self.SEARCH_THRESHOLD {
                                noteResult = note
                                pageResults.append((pageIndex, similarityResult.closestLexicalTarget.isEmpty ? similarityResult.closestSemanticTarget.trimmingCharacters(in: .whitespacesAndNewlines) : similarityResult.closestLexicalTarget.trimmingCharacters(in: .whitespacesAndNewlines), paragraph.trimmingCharacters(in: .whitespacesAndNewlines), similarityResult.getHighestSimilarity()))
                                if similarityResult.getHighestSimilarity() > score_noteText {
                                    score_noteText = similarityResult.getHighestSimilarity()
                                }
                                //logger.info("[Semantic] Note body ('\(closestTarget)') = \(score)")
                            }
                        }
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
                        // logger.info("Document \(document.title) score = \(documentScore)")
                    }
                    // MARK: Document types [TODO]
                }
                let highestDocumentSimilarity = max(highestSemanticSimilarity, highestLexicalSimilarity)
                if highestDocumentSimilarity > self.SEARCH_THRESHOLD {
                    score_noteDocuments = highestDocumentSimilarity
                }
                if isQuestion {
                    var metaInformation = [String]()
                    metaInformation.append("The note '\(note.1.getName())' was created on \(NeoLibrary.getCreationDate(url: note.0)).")
                    metaInformation.append("The note '\(note.1.getName())' was modified on \(NeoLibrary.getModificationDate(url: note.0)).")
                    if !note.1.pages.filter({ $0.getPDFData() != nil }).isEmpty {
                        metaInformation.append("The note '\(note.1.getName())' contains \(Int(note.1.pages.filter({ $0.getPDFData() != nil }).count)) imported PDF pages.")
                    }
                    if !note.1.getDrawingLabels().isEmpty {
                        metaInformation.append("The note \(note.1.getName())' contains drawings. The note '\(note.1.getName())' contains the following drawings: \(note.1.getDrawingLabels().joined(separator: ", "))")
                    }
                    for metaInfo in metaInformation {
                        if let answer = findAnswer(for: originalQuery, in: metaInfo, with: bert) {
                            if !searchResult.questionAnswers.contains(where: {x in
                                (x.1, x.2) == answer
                            }) {
                                searchResult.questionAnswers.append(("[META] Note '\(note.1.getName())'", answer.0, answer.1))
                                if answer.1 > 0.9 {
                                    if noteResult == nil {
                                        logger.info(metaInfo)
                                        noteResult = note
                                    }
                                }
                            }
                        }
                    }
                }
                if let noteResult = noteResult {
                    let score = 2 * score_noteTitle + 2 * score_noteText + 2 * score_noteDrawings + score_noteDocuments
                    logger.info("Search score for note '\(note.1.getName())' = \(score)")
                    searchNoteResult = SearchNoteResult(note: noteResult, noteScore: score, pageHits: pageResults)
                    searchResult.notes.append(searchNoteResult!)
                    if isQuestion {
                        for noteHit in searchNoteResult!.pageHits.filter({$0.3 >= 1.0}).sorted(by: {pageHit1, pageHit2 in pageHit1.3 > pageHit2.3}).prefix(5)  {
                            let phraseType = checkPhraseType(queryPartsOfSpeech: tag(text: noteHit.2, scheme: .lexicalClass))
                            if phraseType == .Sentence {
                                if let answer = findAnswer(for: originalQuery, in: noteHit.2, with: bert) {
                                    if !searchResult.questionAnswers.contains(where: {x in
                                        (x.1, x.2) == answer
                                    }) {
                                        searchResult.questionAnswers.append(("Note '\(note.1.getName())'", answer.0, answer.1))
                                    }
                                }
                            }
                        }
                        for doc in searchResult.documents.filter({$0.1 >= 1.0 && $0.0.documentType != .ALMAAR}).sorted(by: {doc1, doc2 in doc1.1 > doc2.1}).prefix(5) {
                            if let documentDescription = doc.0.getDescription() {
                                if let answer = findAnswer(for: originalQuery, in: documentDescription, with: bert) {
                                    if !searchResult.questionAnswers.contains(where: {x in
                                        (x.1, x.2) == answer
                                    }) {
                                        searchResult.questionAnswers.append(("Document '\(doc.0.title)'", answer.0, answer.1))
                                    }
                                }
                            }
                        }
                    }
                    searchResult.questionAnswers = searchResult.questionAnswers.sorted {answer0, answer1 in
                        answer0.2 > answer1.2
                    }
                }
            }
            searchResult.notes = normalizeNoteSimilarities(noteResults: searchResult.notes)
            searchResult.documents = normalizeDocumentSimilarities(documents: searchResult.documents)
            if filterQuality {
                searchResult.notes = searchResult.notes.filter{$0.noteScore > 0.5}
                searchResult.documents = searchResult.documents.filter{$0.1 > 0.5}
                searchResult.questionAnswers = searchResult.questionAnswers.filter{$0.2 > 0.9}
            }
            resultHandler(searchResult)
        }
        logger.info("Search for query '\(originalQuery)' completed.")
        searchFinishHandler()
    }
    
    private func normalizeNoteSimilarities(noteResults: [SearchNoteResult]) -> [SearchNoteResult]{
        var noteResults = noteResults
        if !noteResults.isEmpty {
            let maxSimilarity = noteResults.map{$0.noteScore}.max()!
            let minSimilarity = 0.0 //notes.map{$0.2}.min()!
            noteResults = noteResults.map {SearchNoteResult(note: $0.note, noteScore: ($0.noteScore - minSimilarity)/(maxSimilarity-minSimilarity), pageHits: $0.pageHits)}
        }
        return noteResults
    }
    private func normalizeDocumentSimilarities(documents: [(Document, Double)]) -> [(Document, Double)] {
        var documents = documents
        if !documents.isEmpty {
            let maxSimilarity = documents.map{$0.1}.max()!
            let minSimilarity = 0.0 //documents.map{$0.1}.min()!
            documents = documents.map {($0.0, ($0.1 - minSimilarity)/(maxSimilarity-minSimilarity))}
        }
        return documents
    }
    
    private func findAnswer(for question: String, in text: String, with bert: BERT = BERT()) -> (String, Double)? {
        let availableLength = 384 - question.count - 3
        if availableLength > 0 {
            let text = String(text[0..<availableLength])
            let answer = bert.findAnswer(for: question, in: text)
            return answer
        }
        else {
            return nil
        }
    }
    
    private enum SearchType: String {
        case Lexical
        case Semantic
    }

    private func getStringSimilarity(betweenQuery query: String, and target: String, wordEmbedding: NLEmbedding) -> StringSimilarityResult {
        let target = target.trimmingCharacters(in: .whitespacesAndNewlines)
        let targetWords = tokenize(text: target, unit: .word)
        let queryWords = tokenize(text: query, unit: .word)
        // MARK: TODO - To improve
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
    
    func isQueryQuestion(text: String) -> Bool {
        let questionKeywords = ["who", "what", "where", "which", "when", "whose", "how"]
        let words = tokenize(text: text, unit: .word).map{$0.lowercased()}
        if text.hasSuffix("?") {
            return true
        }
        for word in words {
            if questionKeywords.contains(word) {
                return true
            }
        }
        return false
    }
}

struct SearchResult {
    typealias Score = Double
    typealias AnswerContext = String
    typealias Answer = String
    var query: String
    var notes = [SearchNoteResult]()
    var documents = [(Document, Score)]()
    var questionAnswers = [(AnswerContext, Answer, Score)]()
}

typealias PageIndex = Int
typealias PageHit = String
typealias PageHitContext = String
typealias PageHitSimilarity = Double

struct SearchNoteResult {
    var note: (URL, Note)
    var noteScore: Double
    var pageHits: [(PageIndex, PageHit, PageHitContext, PageHitSimilarity)]
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

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
    
    func tag(text: String, scheme: NLTagScheme = .lexicalClass) -> [(String, NLTag)] {
        let text = text.lowercased()
        let tagger = NLTagger(tagSchemes: [scheme])
        tagger.string = text
        let tags = tagger.tags(in: text.startIndex..<text.endIndex, unit: .word, scheme: scheme, options: [.omitPunctuation, .omitWhitespace, .joinNames, .joinContractions])
        var tagsTuple = [(String, NLTag)]()
        for tag in tags {
            tagsTuple.append((String(text[tag.1]), tag.0 ?? NLTag.otherWord))
        }
        return tagsTuple
    }
    
    func lemmatize(text: String) -> String {
        let text = text.lowercased()
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
    
    enum WordEmbeddingType {
        case Apple
        case FastText
        case GloVe
    }
    
    func createWordEmbedding(type: WordEmbeddingType = .FastText) -> NLEmbedding {
        switch type {
        case .Apple:
            return NLEmbedding.wordEmbedding(for: .english)!
        case .FastText:
            if let resource = Bundle.main.url(forResource: "FastTextWordEmbedding", withExtension: "mlmodelc"), let embedding = try? NLEmbedding.init(contentsOf: resource) {
                return embedding
            }
            return NLEmbedding.wordEmbedding(for: .english)!
        case .GloVe:
            if let resource = Bundle.main.url(forResource: "GloVeWordEmbedding", withExtension: "mlmodelc"), let embedding = try? NLEmbedding.init(contentsOf: resource) {
                return embedding
            }
            return NLEmbedding.wordEmbedding(for: .english)!
        }
    }
    
    private func cosineDistanceToSimilarity(distance: Double) -> Double {
        let similarity = 1 - distance
        return (1 + similarity)/2.0
    }
    
    //
    private func getTermRelevancy(for terms: [String]) -> [[String]] {
        let wordEmbedding = createWordEmbedding()
        // Pre-processing: lemmatize & lowercase the terms
        var terms = terms
        for i in 0..<terms.count {
            terms[i] = lemmatize(text: terms[i].lowercased())
        }
        // Clustering: separate the terms into semantically related groups/'clusters' which will form separate search queries
        var clusters = [[String]]()
        clusters.append([terms[0]])
        for (idx, term) in terms[1..<terms.count].enumerated() {
            var highestSimilarity = 0.0
            var closestTerm = ""
            for (otherIdx, otherTerm) in terms[0..<terms.count].enumerated() {
                if idx == otherIdx {
                    continue
                }
                let similarity = cosineDistanceToSimilarity(distance: wordEmbedding.distance(between: term, and: otherTerm))
                if similarity > highestSimilarity {
                    highestSimilarity = similarity
                    closestTerm = otherTerm
                }
                //if closestTerm.isEmpty {
                  //  closestTerm = otherTerm
                //}
            }
            var isAdded = false
            if highestSimilarity > 0.5  {
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
        /*for term in terms[1..<terms.count] {
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
        return clusters*/
    }
    
    private func preprocess(query: String, useFullQuery: Bool) -> ([String], Bool) {
        var useFullQuery = useFullQuery
        let queryWords = tokenize(text: query, unit: .word)
        if queryWords.count > 1 { // Longer query
            let allowed = [NLTag.noun, NLTag.adjective, NLTag.number] //  NLTag.verb
            var partsOfSpeech = tag(text: query, scheme: .lexicalClass)
            partsOfSpeech = partsOfSpeech.map{(lemmatize(text: $0.0.lowercased()), $0.1)}
            logger.info(partsOfSpeech)
            let phraseType = checkPhraseType(queryPartsOfSpeech: partsOfSpeech)
            
            var isQuestion = false
            if phraseType == .Sentence {
                isQuestion = isQueryQuestion(text: query)
                if isQuestion {
                    logger.info("Query is a question.")
                    useFullQuery = true
                }
            }
            
            var retainedQueryTerms = [String]()
            // If the part of speech tagger is very inaccurate (tags every word as OtherWord), just retain every query term
            if partsOfSpeech.filter({$0.1 != NLTag.otherWord}).isEmpty {
                retainedQueryTerms = partsOfSpeech.map{$0.0}.filter{!stopwords.contains($0)}
                useFullQuery = true
            }
            else { // Otherwise: Only retain nouns and adjectives
                for pos in partsOfSpeech {
                    if allowed.contains(pos.1) || (pos.1 == NLTag.otherWord && !stopwords.contains(pos.0)) {
                        retainedQueryTerms.append(pos.0)
                    }
                }
            }
            if useFullQuery {
                var uniqueTerms = [String]()
                for term in retainedQueryTerms {
                    if !uniqueTerms.contains(term) {
                        uniqueTerms.append(term)
                    }
                }
                if uniqueTerms.isEmpty {
                    // If for some reason the query is reduced to 0 terms, just return the original query
                    return ([query.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)], isQuestion)
                }
                else {
                    return ([uniqueTerms.map{lemmatize(text: $0)}.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)], isQuestion)
                }
            }
            else {
                let queryClusters = getTermRelevancy(for: retainedQueryTerms)
                var processedQueryClusters = [String]()
                for queryCluster in queryClusters {
                    var uniqueTerms = [String]()
                    for term in queryCluster {
                        if !uniqueTerms.contains(term) {
                            uniqueTerms.append(lemmatize(text: term.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)))
                        }
                    }
                    processedQueryClusters.append(uniqueTerms.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines))
                }
                return (processedQueryClusters, isQuestion)
            }
        }
        else if queryWords.count == 1 { // Keyword query
            return ([lemmatize(text: queryWords[0].lowercased().trimmingCharacters(in: .whitespacesAndNewlines))], false)
        }
        return ([queryWords.joined(separator: " ")], false)
    }
    
    public func search(query originalQuery: String, expandedSearch: Bool = true, useFullQuery: Bool = false, resultHandler: (SearchResult) -> Void, subqueriesHandler: ([String]) -> Void, searchFinishHandler: () -> Void) {
        let originalQuery = originalQuery.lowercased()
        // Keyword, Clause, Extended Clause or Sentence
        let (queries, isQuestion) = preprocess(query: originalQuery, useFullQuery: useFullQuery)
        logger.info("---- Original query: \(originalQuery)")
        if queries.count > 1 {
            logger.info("Query has been divided into \(Int(queries.count)) semantically different queries.")
            subqueriesHandler(queries)
        }
        // Expanded Search means a lower threshold for the lexical search, i.e. more tolerant to minor typos
        let lexicalThreshold = expandedSearch ? 0.8 : 0.9
        let semanticThreshold = expandedSearch ? 0.45 : 0.5
        let searchResultThreshold = expandedSearch ? 0.1 : 0.5
        let searchResultQAThreshold = expandedSearch ? 0.5 : 0.7
        //let bert = BERT()
        let distilbert = DISTILBERT()
        let wordEmbedding = createWordEmbedding()
        var noteIterator = NeoLibrary.getNoteIterator()
        for query in queries {
            var mostRecentNotes = [(URL, Note)]()
            logger.info("-- Query: \(query)")
            noteIterator.reset()
            var searchResult = SearchResult(query: query)
            while let note = noteIterator.next() {
                var score_noteTitle = 0.0
                var score_noteText = 0.0
                var score_noteDrawings = 0.0
                var score_noteDocuments = 0.0
                var noteResult: (URL, Note)?
                var searchNoteResult: SearchNoteResult?
                var searchNoteResultExplanation = ""
                // MARK: Note title
                let similarityResult = self.getStringSimilarity(betweenQuery: query, and: note.1.getName(), wordEmbedding: wordEmbedding)
                if similarityResult.lexicalSimilarity >= lexicalThreshold || similarityResult.semanticSimilarity >= semanticThreshold {
                    noteResult = note
                    score_noteTitle = similarityResult.getHighestSimilarity()
                    if similarityResult.lexicalSimilarity >= lexicalThreshold {
                        searchNoteResultExplanation += "Title: \(Int(similarityResult.lexicalSimilarity*100))% (Lexical: '\(similarityResult.closestLexicalTarget)')\n"
                    }
                    if similarityResult.semanticSimilarity >= semanticThreshold {
                        searchNoteResultExplanation += "Title: \(Int(similarityResult.semanticSimilarity*100))% (Semantic: '\(similarityResult.closestSemanticTarget)')\n"
                    }
                    //logger.info("[Lexical] Note title ('\(closestTarget)') = \(score)")
                }
                // MARK: Note recognized drawings
                let noteDrawingLabels = note.1.getDrawingLabels()
                if !noteDrawingLabels.isEmpty {
                    let similarityResult = self.getStringSimilarity(betweenQuery: query, and: note.1.getDrawingLabels().joined(separator: " "), wordEmbedding: wordEmbedding)
                    if similarityResult.lexicalSimilarity >= lexicalThreshold || similarityResult.semanticSimilarity >= semanticThreshold {
                        noteResult = note
                        score_noteDrawings = similarityResult.getHighestSimilarity()
                        if similarityResult.lexicalSimilarity >= lexicalThreshold {
                            searchNoteResultExplanation += "Drawings: \(Int(similarityResult.lexicalSimilarity*100))% (Lexical: '\(similarityResult.closestLexicalTarget)')\n"
                        }
                        if similarityResult.semanticSimilarity >= semanticThreshold {
                            searchNoteResultExplanation += "Drawings: \(Int(similarityResult.semanticSimilarity*100))% (Semantic: '\(similarityResult.closestSemanticTarget)')\n"
                        }
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
                            if similarityResult.lexicalSimilarity >= lexicalThreshold || similarityResult.semanticSimilarity >= semanticThreshold {
                                noteResult = note
                                pageResults.append((pageIndex, similarityResult.closestLexicalTarget.isEmpty ? similarityResult.closestSemanticTarget.trimmingCharacters(in: .whitespacesAndNewlines) : similarityResult.closestLexicalTarget.trimmingCharacters(in: .whitespacesAndNewlines), paragraph.trimmingCharacters(in: .whitespacesAndNewlines), similarityResult.getHighestSimilarity()))
                                if similarityResult.getHighestSimilarity() > score_noteText {
                                    score_noteText = similarityResult.getHighestSimilarity()
                                    if similarityResult.lexicalSimilarity >= lexicalThreshold {
                                        searchNoteResultExplanation += "Body: \(Int(similarityResult.lexicalSimilarity*100))% (Lexical: '\(similarityResult.closestLexicalTarget)')\n"
                                    }
                                    if similarityResult.semanticSimilarity >= semanticThreshold {
                                        searchNoteResultExplanation += "Body: \(Int(similarityResult.semanticSimilarity*100))% (Semantic: '\(similarityResult.closestSemanticTarget)')\n"
                                    }
                                }
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
                    if similarityResult.lexicalSimilarity >= lexicalThreshold || similarityResult.semanticSimilarity >= semanticThreshold {
                        noteResult = note
                        isDocumentMatching = true
                        score_documentTitle = similarityResult.getHighestSimilarity()
                        if similarityResult.lexicalSimilarity >= lexicalThreshold {
                            searchNoteResultExplanation += "Document title (\(document.title)): \(Int(similarityResult.lexicalSimilarity*100))% (Lexical: '\(similarityResult.closestLexicalTarget)')\n"
                        }
                        if similarityResult.semanticSimilarity >= semanticThreshold {
                            searchNoteResultExplanation += "Document title (\(document.title)): \(Int(similarityResult.semanticSimilarity*100))% (Semantic: '\(similarityResult.closestSemanticTarget)')\n"
                        }
                    }
                    highestSemanticSimilarity = max(highestSemanticSimilarity, similarityResult.semanticSimilarity)
                    highestLexicalSimilarity = max(highestLexicalSimilarity, similarityResult.lexicalSimilarity)
                    // Document description (abstract)
                    if let description = document.getDescription() {
                        let similarityResult = self.getStringSimilarity(betweenQuery: query, and: description, wordEmbedding: wordEmbedding)
                        if similarityResult.lexicalSimilarity >= lexicalThreshold || similarityResult.semanticSimilarity >= semanticThreshold {
                            noteResult = note
                            isDocumentMatching = true
                            score_documentDescription = similarityResult.getHighestSimilarity()
                            if similarityResult.lexicalSimilarity >= lexicalThreshold {
                                searchNoteResultExplanation += "Document description (\(document.title)): \(Int(similarityResult.lexicalSimilarity*100))% (Lexical: '\(similarityResult.closestLexicalTarget)')\n"
                            }
                            if similarityResult.semanticSimilarity >= semanticThreshold {
                                searchNoteResultExplanation += "Document description (\(document.title)): \(Int(similarityResult.semanticSimilarity*100))% (Semantic: '\(similarityResult.closestSemanticTarget)')\n"
                            }
                        }
                        highestSemanticSimilarity = max(highestSemanticSimilarity, similarityResult.semanticSimilarity)
                        highestLexicalSimilarity = max(highestLexicalSimilarity, similarityResult.lexicalSimilarity)
                    }
                    if isDocumentMatching && searchResult.documents.filter({$0.0 == document}).isEmpty {
                        let documentScore = score_documentTitle + score_documentDescription
                        searchResult.documents.append((document, documentScore))
                        // logger.info("Document \(document.title) score = \(documentScore)")
                    }
                }
                let highestDocumentSimilarity = max(highestSemanticSimilarity, highestLexicalSimilarity)
                if highestDocumentSimilarity > semanticThreshold {
                    score_noteDocuments = highestDocumentSimilarity
                }
                if isQuestion {
                    var metaInformation = [String]()
                    metaInformation.append("The note \(note.1.getName()) was created on \(NeoLibrary.getCreationDate(url: note.0)).")
                    metaInformation.append("The note \(note.1.getName()) was modified on \(NeoLibrary.getModificationDate(url: note.0)).")
                    /*if !note.1.pages.filter({ $0.getPDFData() != nil }).isEmpty {
                        metaInformation.append("The note \(note.1.getName()) contains \(Int(note.1.pages.filter({ $0.getPDFData() != nil }).count)) imported PDF pages.")
                    }
                    if !note.1.getDrawingLabels().isEmpty {
                        metaInformation.append("The note \(note.1.getName()) contains drawings. The note '\(note.1.getName())' contains the following drawings: \(note.1.getDrawingLabels().joined(separator: ", "))")
                    }*/
                    for metaInfo in metaInformation {
                        if let answer = findAnswer(for: originalQuery, in: metaInfo, with: distilbert) {
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
                    searchNoteResult = SearchNoteResult(note: noteResult, noteScore: score, pageHits: pageResults, resultExplanation: searchNoteResultExplanation)
                    searchResult.notes.append(searchNoteResult!)
                    if isQuestion {
                        for noteHit in searchNoteResult!.pageHits.filter({$0.3 >= 1.0}).sorted(by: {pageHit1, pageHit2 in pageHit1.3 > pageHit2.3}).prefix(5)  {
                            let phraseType = checkPhraseType(queryPartsOfSpeech: tag(text: noteHit.2, scheme: .lexicalClass))
                            if phraseType == .Sentence {
                                if let answer = findAnswer(for: originalQuery, in: noteHit.2, with: distilbert) {
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
                                if let answer = findAnswer(for: originalQuery, in: documentDescription, with: distilbert) {
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
                if mostRecentNotes.isEmpty {
                    mostRecentNotes.append(note)
                }
                else {
                    var mostRecentUpdated = false
                    for (idx, n) in mostRecentNotes.enumerated() {
                        if NeoLibrary.getModificationDate(url: note.0) > NeoLibrary.getModificationDate(url: n.0) {
                            mostRecentNotes.insert(note, at: idx)
                            mostRecentUpdated = true
                            break
                        }
                    }
                    if mostRecentNotes.count < 5 && !mostRecentUpdated {
                        mostRecentNotes.append(note)
                    }
                }
            }
            if !mostRecentNotes.isEmpty {
                if let answer = findAnswer(for: originalQuery, in: "Your most recent notes are \(mostRecentNotes.map{$0.1.getName()}.joined(separator: ", ")).", with: distilbert) {
                    searchResult.questionAnswers.append(("[META]", answer.0, answer.1))
                }
            }
            searchResult.notes = normalizeNoteSimilarities(noteResults: searchResult.notes)
            searchResult.documents = normalizeDocumentSimilarities(documents: searchResult.documents)
            searchResult.notes = searchResult.notes.filter{$0.noteScore >= searchResultThreshold}
            searchResult.documents = searchResult.documents.filter{$0.1 >= searchResultThreshold}
            searchResult.questionAnswers = searchResult.questionAnswers.filter{$0.2 >= searchResultQAThreshold}
            resultHandler(searchResult)
            
            if searchResult.notes.isEmpty {
                let queryWords = tokenize(text: query, unit: .word)
                if queryWords.count > 1 {
                    
                }
            }
        }
        logger.info("Search for query '\(originalQuery)' completed.")
        searchFinishHandler()
    }
    
    private func normalizeNoteSimilarities(noteResults: [SearchNoteResult]) -> [SearchNoteResult]{
        var noteResults = noteResults
        if !noteResults.isEmpty {
            let maxSimilarity = noteResults.map{$0.noteScore}.max()!
            let minSimilarity = 0.0
            noteResults = noteResults.map {SearchNoteResult(note: $0.note, noteScore: ($0.noteScore - minSimilarity)/(maxSimilarity-minSimilarity), pageHits: $0.pageHits, resultExplanation: $0.resultExplanation)}
        }
        return noteResults
    }
    private func normalizeDocumentSimilarities(documents: [(Document, Double)]) -> [(Document, Double)] {
        var documents = documents
        if !documents.isEmpty {
            let maxSimilarity = documents.map{$0.1}.max()!
            let minSimilarity = 0.0
            documents = documents.map {($0.0, ($0.1 - minSimilarity)/(maxSimilarity-minSimilarity))}
        }
        return documents
    }
    
    private func findAnswer(for question: String, in text: String, with distilbert: DISTILBERT = DISTILBERT()) -> (String, Double)? {
        let question = question.hasSuffix("?") ? question : question.hasSuffix(".") || question.hasSuffix("!") ? question[0..<question.count-1] + "?" : question + "?"
        let availableLength = 384 - question.count - 3
        if availableLength > 0 {
            let text = String(text[0..<availableLength])
            let answer = distilbert.predict(question: question, context: text)
            return answer
        }
        else {
            return nil
        }
    }
    
    public func suggestKeywords(for keyword: String) {
        var noteIterator = NeoLibrary.getNoteIterator()
        let wordEmbedding = NLEmbedding.wordEmbedding(for: .english)!
        logger.info(wordEmbedding.neighbors(for: keyword, maximumCount: 5))
        while let note = noteIterator.next() {
            let keywords = SKTextRank.shared.extractKeywords(text: note.1.getText(option: .FullText, parse: true) + "\n" + note.1.getDocuments().map{$0.getDescription() ?? ""}.filter{!$0.isEmpty}.joined(separator: " "), numberOfKeywords: 10, biased: false, usePostProcessing: true)
            logger.info("\(note.1.getName()) - \(keywords)")
            logger.info("\(note.1.getName()) - \(keywords.filter {SemanticSearch.shared.getStringSimilarity(betweenQuery: keyword, and: $0, wordEmbedding: wordEmbedding).semanticSimilarity > 0.5})")
        }
    }
    
    private enum SearchType: String {
        case Lexical
        case Semantic
    }

    private func getStringSimilarity(betweenQuery query: String, and target: String, wordEmbedding: NLEmbedding) -> StringSimilarityResult {
        let target = target.trimmingCharacters(in: .whitespacesAndNewlines)
        let targetWords = tokenize(text: target, unit: .word).filter {!stopwords.contains($0) && $0.count > 2}
        let queryWords = tokenize(text: query, unit: .word)
        // MARK: TODO - To improve
        var semanticSimilarities = [Double]()
        var lexicalSimilarities = [Double]()
        var closestSemanticTarget = [String]()
        var closestLexicalTarget = [String]()
        for queryWord in queryWords {
            var highestSemanticSimilarity = 0.0 // Higher is better - Semantic similarity
            var highestLexicalSimilarity = 0.0 // Higher is better - Damerau-Levenshtein ratio
            var temp_closestSemanticTarget = ""
            var temp_closestLexicalTarget = ""
            for word in targetWords {
                let word = word.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                let semanticSimilarity = cosineDistanceToSimilarity(distance: wordEmbedding.distance(between: queryWord, and: word))
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
            closestSemanticTarget.append(temp_closestSemanticTarget)
            closestLexicalTarget.append(temp_closestLexicalTarget)
        }
        var semanticSimilarity = 0.0
        if !semanticSimilarities.isEmpty {
            semanticSimilarity = Double(semanticSimilarities.reduce(0.0, +)) / Double(semanticSimilarities.count)
        }
        var lexicalSimilarity = 0.0
        if !lexicalSimilarities.isEmpty {
            lexicalSimilarity = Double(lexicalSimilarities.reduce(0.0, +)) / Double(lexicalSimilarities.count)
        }
        let result = StringSimilarityResult(closestSemanticTarget.joined(separator: " "), closestLexicalTarget.joined(separator: " "), semanticSimilarity, lexicalSimilarity)
        return result
    }
    
    enum PhraseType: String {
        case Keyword = "Keyword"
        case Clause = "Clause"
        case ExtendedClause = "Extended Clause"
        case Sentence = "Sentence"
    }
    
    func checkPhraseType(queryPartsOfSpeech: [(String, NLTag?)]) -> PhraseType {
        if queryPartsOfSpeech.count == 1 {
            return PhraseType.Keyword
        }
        var hasSubject = false
        var hasVerb = false
        for tag in queryPartsOfSpeech {
            if let lexicalClass = tag.1 {
                if lexicalClass == NLTag.noun || lexicalClass == NLTag.pronoun {
                    hasSubject = true
                }
                else if lexicalClass == NLTag.verb {
                    hasVerb = true
                }
                if hasSubject && hasVerb {
                    return PhraseType.Sentence
                }
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
        let tags = tag(text: text, scheme: .lexicalClass)
        if !tags.isEmpty {
            if tags.first!.1 == NLTag.verb {
                return true
            }
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
    var resultExplanation: String = ""
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

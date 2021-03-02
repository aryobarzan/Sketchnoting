//
//  SemanticSearch.swift
//  Sketchnoting
//
//  Created by Aryobarzan on 17/02/2021.
//  Copyright © 2021 Aryobarzan. All rights reserved.
//

import Foundation
import NaturalLanguage
import MLKitEntityExtraction

class SemanticSearch {
    
    public static let shared = SemanticSearch()
    private init() {
        locationSynonyms = ["location"]
        var synonyms = wordEmbedding!.neighbors(for: "location", maximumCount: 5)
        for syn in synonyms {
            locationSynonyms.append(syn.0.lowercased())
        }
        personSynonyms = ["person"]
        synonyms = wordEmbedding!.neighbors(for: "person", maximumCount: 5)
        for syn in synonyms {
            personSynonyms.append(syn.0.lowercased())
        }
        queue.maxConcurrentOperationCount = 4
        
        downloadEntityExtractorModel()
    }
    
    private let SEARCH_THRESHOLD = 0.8
    private let DRAWING_THRESHOLD = 0.7
    private let KEYWORD_THRESHOLD = 0.6
    private var locationSynonyms: [String]
    private var personSynonyms: [String]
    
    private let entityExtractor = EntityExtractor.entityExtractor(options: EntityExtractorOptions(modelIdentifier: EntityExtractionModelIdentifier.english))
    private let wordEmbedding = NLEmbedding.wordEmbedding(for: .english)
    private let sentenceEmbedding = NLEmbedding.sentenceEmbedding(for: .english)
    
    private let queue = OperationQueue()
    
    func downloadEntityExtractorModel() {
        entityExtractor.downloadModelIfNeeded(completion: { error in
            if error == nil {
                log.info("Entity extraction model is ready.")
            }
            else {
                log.error("Entity extraction model not available: \(error!)")
            }
        })
    }
    
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
        let tags = tagger.tags(in: text.startIndex..<text.endIndex, unit: .word, scheme: scheme, options: [.omitPunctuation, .omitWhitespace, .joinNames])
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
        if tags.count > 0 && tags[0].0 != nil {
            textLemmatized = tags[0].0!.rawValue
        }
        return textLemmatized
    }
    
    func neighbors(word: String, maximumCount: Int = 5) -> [(String, Double)] {
        if let wordEmbedding = wordEmbedding {
            return wordEmbedding.neighbors(for: word, maximumCount: maximumCount)
        }
        return [(String, Double)]()
    }
    
    func wordDistance(between: String, and: String) -> Double {
        if let wordEmbedding = wordEmbedding {
            return wordEmbedding.distance(between: between, and: and, distanceType: .cosine)
        }
        return -1.0
    }
    
    func sentenceDistance(between: String, and: String) -> Double {
        if let sentenceEmbedding = sentenceEmbedding {
            return sentenceEmbedding.distance(between: between, and: and, distanceType: .cosine)
        }
        return -1.0
    }
    
    func extractEntities(text: String, entityCompletion: (DateTimeEntity?) -> Void) {
        self.dateTimeEntity = nil
        let params = EntityExtractionParams()
        params.referenceTime = Date();
        params.referenceTimeZone = TimeZone(identifier: "GMT");
        params.preferredLocale = Locale(identifier: "en-US");
        params.typesFilter = Set([EntityType.address, EntityType.dateTime])
        
        entityExtractor.annotateText(
            text,
            params: params) { result, error in
            if error == nil {
                if let annotations = result {
                    for annotation in annotations {
                        let entities = annotation.entities
                        for entity in entities {
                            switch entity.entityType {
                            case EntityType.dateTime:
                                guard let dateTimeEntity = entity.dateTimeEntity else {
                                    log.error("No date/time entity detected.")
                                    return
                                }
                                log.info("Date/time entity detected.")
                                log.info("Granularity: \(dateTimeEntity.dateTimeGranularity)")
                                log.info("DateTime: \(dateTimeEntity.dateTime)")
                                self.dateTimeEntity = dateTimeEntity
                            default:
                                log.info("Entity: \(entity)");
                            }
                        }
                    }
                }
            }
        }
    }
    private var dateTimeEntity: DateTimeEntity?
    
    func getDateTimeEntity() -> DateTimeEntity? {
        return dateTimeEntity
    }
    
    // temporary
    func getCurrentTime() -> Int64 {
        return Int64(Date().timeIntervalSince1970 * 1000)
    }
    
    func search(query: String, notes: [(URL, Note)], expandedSearch: Bool = true, searchHandler: ((SearchResult) -> Void)?) {
        // missing: note tags, note title
        let tagger = NLTagger(tagSchemes: [.lemma])
        // let queryWords = tokenize(text: query, unit: .word)
        let queryPartsOfSpeech = tag(text: query, scheme: .lexicalClass)
        let queryEntities = tag(text: query, scheme: .nameType)
        // Extract nouns from the query
        var queryNouns = [(String, String)]()
        for term in queryPartsOfSpeech {
            if term.1 == "Noun" || term.1 == "Other" {
                tagger.string = term.0
                let tags = tagger.tags(in: term.0.startIndex..<term.0.endIndex, unit: .word, scheme: .lemma, options: [.omitPunctuation, .omitWhitespace])
                var termLemmatized = term.0
                if tags.count > 0 && tags[0].0 != nil {
                    termLemmatized = tags[0].0!.rawValue
                }
                queryNouns.append((termLemmatized, term.1))
            }
        }
        let queryType = checkPhraseType(queryPartsOfSpeech: queryPartsOfSpeech)
        log.info("Performing semantic search on query of type: \(queryType.rawValue)")
        var lexicalThreshold = 1.0
        if expandedSearch {
            lexicalThreshold = 0.90
        }
        // MARK: Keyword
        if queryType == .Keyword {
            for note in notes {
                queue.addOperation {
                    let searchResult = self.searchKeyword(query: query, in: note, lexicalThreshold: lexicalThreshold, queryEntityType: queryEntities.isEmpty ? "Other" : queryEntities[0].1)
                    if let searchHandler = searchHandler {
                        searchHandler(searchResult)
                    }
                }
            }
        }
        // MARK: Clause or ExtendedClause or Sentence
        else {
            for note in notes {
                log.info("- Searching note: \(note.1.getName())")
                queue.addOperation {
                    let searchResult = self.searchSentence(query: query, note: note, lexicalThreshold: lexicalThreshold, queryNouns: queryNouns, queryEntities: queryEntities)
                    if let searchHandler = searchHandler {
                        searchHandler(searchResult)
                    }
                }
            }
        }
        queue.addBarrierBlock {
            log.info("Semantic search completed.")
        }
    }
    
    private enum SearchType: String {
        case Lexical
        case Semantic
    }
    
    private func performStringSimilarity(between query: String, and words: [String], wordEmbedding: NLEmbedding) -> (Double, String, SearchType) {
        var minimumDistance = 999.0 // lower is better
        var levenshteinRatio = 0.0 // higher is better
        var similarWord = ""
        let query = query.lowercased()
        for word in words {
            // Semantic
            let distance = wordEmbedding.distance(between: query, and: word.lowercased())
            if distance == 2.0 { // Meaning: word is unknown to word embedder (has no vector representation)
                // Lexical
                let levenshteinDistance = query.levenshtein(word.lowercased())
                let lengthsSum = Double(query.count + word.count)
                let temp: Double = (lengthsSum - Double(levenshteinDistance))/lengthsSum
                if temp > levenshteinRatio {
                    levenshteinRatio = temp
                    similarWord = word
                }
                if levenshteinRatio == 1.0 { // Exact match found
                    break
                }
            }
            else if distance < minimumDistance {
                minimumDistance = distance
                similarWord = word
            }
        }
        // No semantic result, hence return lexical similarity
        if minimumDistance >= 2.0 {
            return (levenshteinRatio, similarWord, SearchType.Lexical)
        }
        // Semantic result is returned
        else {
            return (minimumDistance, similarWord, SearchType.Semantic)
        }
    }
    
    private func performStringSimilarity(between query: String, and sentences: [String], sentenceEmbedding: NLEmbedding) -> (Double, Double) {
        var minimumDistance = 999.0
        var levenshteinRatio = 0.0
        var similarSentence = ""
        for sentence in sentences {
            let distance = sentenceEmbedding.distance(between: query.lowercased(), and: sentence.lowercased())
            if distance == 2.0 { // Meaning: sentence is unknown to sentence embedder (has no vector representation)
                let levenshteinDistance = query.lowercased().levenshtein(sentence.lowercased())
                let lengthsSum = Double(query.count + sentence.count)
                let temp: Double = (lengthsSum - Double(levenshteinDistance))/lengthsSum
                if temp > levenshteinRatio {
                    levenshteinRatio = temp
                    similarSentence = sentence
                }
                if levenshteinRatio == 1.0 { // Exact match found
                    break
                }
            }
            if distance < minimumDistance {
                minimumDistance = distance
            }
        }
        return (minimumDistance, levenshteinRatio)
    }
    
    private func searchKeyword(query: String, in note: (URL, Note), lexicalThreshold: Double = 1.0, queryEntityType: String) -> SearchResult {
        // var query = lemmatize(text: query).lowercased()
        var searchResult = SearchResult()
        if let wordEmbedding = NLEmbedding.wordEmbedding(for: .english) {
            var time = self.getCurrentTime()
            log.info("- Searching note: \(note.1.getName())")
            var isMatch = false
            // MARK: Body search
            let noteBodyWords = self.tokenize(text: note.1.getText(option: .FullText), unit: .word)
            let (similarityResult, similarWord, searchType) = performStringSimilarity(between: query.lowercased(), and: noteBodyWords, wordEmbedding: wordEmbedding)
            switch searchType {
            case .Lexical:
                searchResult.bodyScore = 1.0 * max(0.01, similarityResult)
                if similarityResult >= lexicalThreshold {
                    searchResult.note = note
                    isMatch = true
                    log.info("[Lexical] Body ('\(similarWord)') = \(similarityResult)")
                    break
                }
            case .Semantic:
                searchResult.bodyScore = 1.0 / max(0.01, similarityResult)
                if similarityResult <= SEARCH_THRESHOLD {
                    log.info("[Semantic] Body ('\(similarWord)') = \(similarityResult)")
                    searchResult.note = note
                    isMatch = true
                    break
                }
            }
            log.info("Analysis of note body: \(self.getCurrentTime() - time)ms")
            // MARK: Drawings search
            if !isMatch {
                time = self.getCurrentTime()
                let (similarityResult, similarWord, searchType) = performStringSimilarity(between: query.lowercased(), and: note.1.getDrawingLabels(), wordEmbedding: wordEmbedding)
                switch searchType {
                case .Lexical:
                    searchResult.drawingScore = 1.0 * max(0.01, similarityResult)
                    if similarityResult >= lexicalThreshold {
                        searchResult.note = note
                        isMatch = true
                        log.info("[Lexical] Drawing ('\(similarWord)') = \(similarityResult)")
                        break
                    }
                case .Semantic:
                    searchResult.drawingScore = 1.0 / max(0.01, similarityResult)
                    if similarityResult <= SEARCH_THRESHOLD {
                        log.info("[Semantic] Drawing ('\(similarWord)') = \(similarityResult)")
                        searchResult.note = note
                        isMatch = true
                        break
                    }
                }
                log.info("Analysis of note drawings: \(self.getCurrentTime() - time)ms")
            }
            // MARK: Documents search
            time = self.getCurrentTime()
            var foundInDocuments = false
            var documentScore: Double = 0.0
            var tempScore: Double = 0.0
            for document in note.1.getDocuments() {
                // MARK: Document Description
                if let description = document.description {
                    let words = self.tokenize(text: description, unit: .word)
                    let (similarityResult, similarWord, searchType) = performStringSimilarity(between: query.lowercased(), and: words, wordEmbedding: wordEmbedding)
                    switch searchType {
                    case .Lexical:
                        documentScore = 1.0 * max(0.01, similarityResult)
                        if similarityResult >= lexicalThreshold {
                            searchResult.documents.append(document)
                            foundInDocuments = true
                            log.info("[Lexical] Document '\(document.title)' Description ('\(similarWord)') = \(similarityResult)")
                        }
                        break
                    case .Semantic:
                        documentScore = 1.0 / max(0.01, similarityResult)
                        if similarityResult <= SEARCH_THRESHOLD {
                            log.info("[Semantic] Document '\(document.title)' Description ('\(similarWord)') = \(similarityResult)")
                            searchResult.documents.append(document)
                            foundInDocuments = true
                        }
                        break
                    }
                }
                // MARK: Document Title
                let documentTitleWords = self.tokenize(text: document.title, unit: .word)
                let (similarityResult, similarWord, searchType) = performStringSimilarity(between: query.lowercased(), and: documentTitleWords, wordEmbedding: wordEmbedding)
                switch searchType {
                case .Lexical:
                    tempScore = 1.0 * max(0.01, similarityResult)
                    if similarityResult >= lexicalThreshold {
                        searchResult.documents.append(document)
                        foundInDocuments = true
                        log.info("[Lexical] Document '\(document.title)' Title ('\(similarWord)') = \(similarityResult)")
                    }
                    break
                case .Semantic:
                    tempScore = 1.0 / max(0.01, similarityResult)
                    if similarityResult <= KEYWORD_THRESHOLD {
                        log.info("[Semantic] Document '\(document.title)' Title ('\(similarWord)') = \(similarityResult)")
                        searchResult.documents.append(document)
                        foundInDocuments = true
                    }
                    break
                }
                documentScore = tempScore > documentScore ? tempScore : documentScore
                // MARK: Document entities - to adjust
                /*if let tagmeDocument = document as? TAGMEDocument, let categories = tagmeDocument.categories {
                    if queryEntityType == NLTag.placeName.rawValue {
                        var foundLocation = false
                        for category in categories {
                            for locationSynonym in self.locationSynonyms {
                                let similarity = wordEmbedding.distance(between: category, and: locationSynonym, distanceType: .cosine)
                                if similarity <= 1.0 {
                                    log.info("Found location related document: \(category) - \(locationSynonym)")
                                    foundLocation = true
                                    searchResult.locationDocuments.append(document)
                                    break
                                }
                            }
                            if foundLocation {
                                break
                            }
                        }
                    }
                    else if queryEntityType == NLTag.personalName.rawValue {
                        var foundPerson = false
                        for category in categories {
                            for personSynonym in self.personSynonyms {
                                let similarity = wordEmbedding.distance(between: category, and: personSynonym, distanceType: .cosine)
                                if similarity <= 1.0 {
                                    log.info("Found person related document: \(category) - \(personSynonym)")
                                    foundPerson = true
                                    searchResult.personDocuments.append(document)
                                    break
                                }
                            }
                            if foundPerson {
                                break
                            }
                        }
                    }
                }*/
            }
            searchResult.documentScore = documentScore
            searchResult.documents = Array(Set(searchResult.documents))
            if foundInDocuments && !isMatch {
                searchResult.note = note
            }
            log.info("Analysis of documents for note: \(self.getCurrentTime() - time)ms")
        }
        return searchResult
    }
    
    private func searchSentence(query: String, note: (URL, Note), lexicalThreshold: Double = 1.0, queryNouns: [(String, String)], queryEntities: [(String, String)]) -> SearchResult {
        var searchResult = SearchResult()
        if let sentenceEmbedding = NLEmbedding.sentenceEmbedding(for: .english), let wordEmbedding = NLEmbedding.wordEmbedding(for: .english) {
            var isMatch = false
            // MARK: Body search
            let body = note.1.getText()
            let noteBodySentences = self.tokenize(text: body, unit: .sentence)
            let (minimumBodyDistance, highestBodyLevenshteinMatchPercentage) = performStringSimilarity(between: query.lowercased(), and: noteBodySentences, sentenceEmbedding: sentenceEmbedding)
            if minimumBodyDistance <= self.SEARCH_THRESHOLD || highestBodyLevenshteinMatchPercentage >= lexicalThreshold {
                searchResult.note = note
                isMatch = true
                log.info("Body similarity threshold achieved: \(minimumBodyDistance) / \(highestBodyLevenshteinMatchPercentage)")
            }
            // MARK: Drawings search
            if !isMatch {
                for term in queryNouns {
                    let (similarityResult, similarWord, searchType) = performStringSimilarity(between: term.1.lowercased(), and: note.1.getDrawingLabels(), wordEmbedding: wordEmbedding)
                    switch searchType {
                    case .Lexical:
                        searchResult.drawingScore = 1.0 * max(0.01, similarityResult)
                        if similarityResult >= lexicalThreshold {
                            log.info("[Lexical] Drawing ('\(similarWord)') = \(similarityResult)")
                            if !isMatch {
                                searchResult.note = note
                                isMatch = true
                            }
                        }
                        break
                    case .Semantic:
                        searchResult.drawingScore = 1.0 / max(0.01, similarityResult)
                        if similarityResult <= DRAWING_THRESHOLD {
                            log.info("[Semantic] Drawing ('\(similarWord)') = \(similarityResult)")
                            if !isMatch {
                                searchResult.note = note
                                isMatch = true
                            }
                        }
                        break
                    }
                    if isMatch {
                        break
                    }
                }
            }
            // MARK: Documents search
            var foundInDocuments = false
            for document in note.1.getDocuments() {
                // MARK: Document Description
                if let description = document.description {
                    let documentDescriptionSentences = self.tokenize(text: description, unit: .sentence)
                    let (minimumBodyDistance, highestBodyLevenshteinMatchPercentage) = performStringSimilarity(between: query.lowercased(), and: documentDescriptionSentences, sentenceEmbedding: sentenceEmbedding)
                    if minimumBodyDistance <= self.SEARCH_THRESHOLD || highestBodyLevenshteinMatchPercentage >= lexicalThreshold {
                        searchResult.documents.append(document)
                        foundInDocuments = true
                        log.info("Found in document description of: \(document.title)")
                    }
                }
                // MARK: Document Title
                let (minimumBodyDistance, highestBodyLevenshteinMatchPercentage) = performStringSimilarity(between: query.lowercased(), and: [document.title], sentenceEmbedding: sentenceEmbedding)
                if minimumBodyDistance <= self.SEARCH_THRESHOLD || highestBodyLevenshteinMatchPercentage >= lexicalThreshold {
                    log.info("Found match in title of document: \(document.title)")
                    if !searchResult.documents.contains(document) {
                        searchResult.documents.append(document)
                        foundInDocuments = true
                    }
                }
                // MARK: Document entities - to adjust
                if let tagmeDocument = document as? TAGMEDocument, let categories = tagmeDocument.categories {
                    for entity in queryEntities {
                        if entity.1 == NLTag.placeName.rawValue {
                            var foundLocation = false
                            for category in categories {
                                for locationSynonym in self.locationSynonyms {
                                    let similarity = wordEmbedding.distance(between: category, and: locationSynonym, distanceType: .cosine)
                                    if similarity <= self.SEARCH_THRESHOLD {
                                        log.info("Found location related document: \(category) - \(locationSynonym)")
                                        foundLocation = true
                                        searchResult.locationDocuments.append(document)
                                        break
                                    }
                                }
                                if foundLocation {
                                    break
                                }
                            }
                        }
                        else if entity.1 == NLTag.personalName.rawValue {
                            var foundPerson = false
                            for category in categories {
                                for personSynonym in self.personSynonyms {
                                    let similarity = wordEmbedding.distance(between: category, and: personSynonym, distanceType: .cosine)
                                    if similarity <= self.SEARCH_THRESHOLD {
                                        log.info("Found person related document: \(category) - \(personSynonym)")
                                        foundPerson = true
                                        searchResult.personDocuments.append(document)
                                        break
                                    }
                                }
                                if foundPerson {
                                    break
                                }
                            }
                        }
                    }
                }
            }
            if foundInDocuments && !isMatch {
                searchResult.note = note
            }
        }
        return searchResult
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
}

struct SearchResult {
    var note: (URL, Note)?
    var documents = [Document]()
    var locationDocuments = [Document]()
    var personDocuments = [Document]()
    
    var bodyScore: Double = 0.0
    var drawingScore: Double = 0.0
    var documentScore: Double = 0.0
}

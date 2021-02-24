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
    
    func search(query: String, notes: [(URL, Note)], searchHandler: ((SearchResult) -> Void)?) {
        // missing: note tags, note title
        let tagger = NLTagger(tagSchemes: [.lemma])
        let queryWords = tokenize(text: query, unit: .word)
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
        
        // MARK: Keyword
        if queryType == .Keyword {
            for note in notes {
                queue.addOperation {
                    let searchResult = self.searchKeyword(query: query, in: note, queryEntityType: queryEntities.isEmpty ? "Other" : queryEntities[0].1)
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
                    let searchResult = self.searchSentence(query: query, note: note, queryNouns: queryNouns, queryEntities: queryEntities)
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
    
    private func performStringSimilarity(between query: String, and words: [String], wordEmbedding: NLEmbedding) -> (Double, Double) {
        var minimumDistance = 999.0
        var levenshteinMatchPercentage = 0.0
        for word in words {
            let distance = wordEmbedding.distance(between: query.lowercased(), and: word.lowercased())
            if distance == 2.0 { // Meaning: word is unknown to word embedder (has no vector representation)
                let levenshteinDistance = query.lowercased().levenshtein(word.lowercased())
                if levenshteinDistance == 0 {
                    levenshteinMatchPercentage = 1.0
                    break
                }
                else {
                    let temp = 1.0 / Double(levenshteinDistance)
                    if temp > levenshteinMatchPercentage {
                        levenshteinMatchPercentage = temp
                    }
                }
            }
            if distance < minimumDistance {
                minimumDistance = distance
            }
        }
        return (minimumDistance, levenshteinMatchPercentage)
    }
    
    private func searchKeyword(query: String, in note: (URL, Note), queryEntityType: String) -> SearchResult {
        // var query = lemmatize(text: query).lowercased()
        var searchResult = SearchResult()
        if let wordEmbedding = NLEmbedding.wordEmbedding(for: .english) {
            var time = self.getCurrentTime()
            log.info("- Searching note: \(note.1.getName())")
            var isMatch = false
            // MARK: Body search
            let noteBodyWords = self.tokenize(text: note.1.getText(option: .FullText), unit: .word)
            let (minimumBodyDistance, highestBodyLevenshteinMatchPercentage) = performStringSimilarity(between: query.lowercased(), and: noteBodyWords, wordEmbedding: wordEmbedding)
            if minimumBodyDistance <= self.SEARCH_THRESHOLD || highestBodyLevenshteinMatchPercentage >= 0.75 {
                searchResult.note = note
                isMatch = true
                log.info("Body similarity threshold achieved: \(minimumBodyDistance) / \(highestBodyLevenshteinMatchPercentage)")
            }
            log.info("Analysis of note body: \(self.getCurrentTime() - time)ms")
            // MARK: Drawings search
            if !isMatch {
                time = self.getCurrentTime()
                let (minimumDrawingDistance, highestDrawingLevenshteinMatchPercentage) = performStringSimilarity(between: query.lowercased(), and: note.1.getDrawingLabels(), wordEmbedding: wordEmbedding)
                if minimumDrawingDistance <= self.DRAWING_THRESHOLD || highestDrawingLevenshteinMatchPercentage >= 0.75 {
                    log.info("Drawing similarity threshold achieved.")
                    if !isMatch {
                        searchResult.note = note
                        isMatch = true
                    }
                }
                log.info("Analysis of note drawings: \(self.getCurrentTime() - time)ms")
            }
            // MARK: Documents search
            time = self.getCurrentTime()
            var foundInDocuments = false
            for document in note.1.getDocuments() {
                // MARK: Document Description
                if let description = document.description {
                    let words = self.tokenize(text: description, unit: .word)
                    let (minimumDocumentDescriptionDistance, highestDocumentDescriptionLevenshteinMatchPercentage) = performStringSimilarity(between: query.lowercased(), and: words, wordEmbedding: wordEmbedding)
                    if minimumDocumentDescriptionDistance <= self.SEARCH_THRESHOLD || highestDocumentDescriptionLevenshteinMatchPercentage >= 0.75 {
                        log.info("Found in document: \(document.title)")
                        searchResult.documents.append(document)
                        foundInDocuments = true
                    }
                }
                // MARK: Document Title
                let documentTitleWords = self.tokenize(text: document.title, unit: .word)
                let (minimumDocumentTitleDistance, highestDocumentTitleLevenshteinMatchPercentage) = performStringSimilarity(between: query.lowercased(), and: documentTitleWords, wordEmbedding: wordEmbedding)
                if minimumDocumentTitleDistance <= self.KEYWORD_THRESHOLD || highestDocumentTitleLevenshteinMatchPercentage >= 0.75 {
                    log.info("Found query in title of document: \(document.title) [\(document.documentType.rawValue)]")
                    if !searchResult.documents.contains(document) {
                        searchResult.documents.append(document)
                        foundInDocuments = true
                    }
                }
                // MARK: Document entities - to adjust
                if let tagmeDocument = document as? TAGMEDocument, let categories = tagmeDocument.categories {
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
                }
            }
            if foundInDocuments && !isMatch {
                searchResult.note = note
            }
            log.info("Analysis of documents for note: \(self.getCurrentTime() - time)ms")
        }
        return searchResult
    }
    
    /*private func searchClause() {
        let sentenceEmbedding = NLEmbedding.sentenceEmbedding(for: .english)!
        let wordEmbedding = NLEmbedding.wordEmbedding(for: .english)!
        var searchResult = SearchResult()
        var time = self.getCurrentTime()
        log.info("- Searching note: \(note.1.getName())")
        var isMatch = false
        // MARK: Body search
        let body = note.1.getText(option: .FullText)
        let noteWords = self.tokenize(text: body, unit: .word)
        var averageSimilarity = 0.0
        for queryWord in queryWords {
            var minimumSimilarity = 999.0
            for word in noteWords {
                let similarity = wordEmbedding.distance(between: queryWord.lowercased(), and: word.lowercased(), distanceType: .cosine)
                if similarity < minimumSimilarity {
                    minimumSimilarity = similarity
                }
            }
            averageSimilarity += minimumSimilarity
        }
        averageSimilarity /= Double(queryWords.count)
        if averageSimilarity <= self.SEARCH_THRESHOLD {
            searchResult.note = note
            isMatch = true
            log.info("Body similarity threshold achieved: \(averageSimilarity)")
        }
        log.info("Analysis of note body: \(self.getCurrentTime() - time)ms")
        // MARK: Drawings search
        time = self.getCurrentTime()
        if !isMatch {
            averageSimilarity = 0.0
            for term in queryNouns {
                var minimumSimilarity = 999.0
                for drawing in note.1.getDrawingLabels() {
                    let similarity = wordEmbedding.distance(between: term.0.lowercased(), and: self.lemmatize(text: drawing).lowercased())
                    log.info("\(term.0) - \(drawing): \(similarity)")
                    if similarity < minimumSimilarity {
                        minimumSimilarity = similarity
                    }
                }
                averageSimilarity += minimumSimilarity
            }
            averageSimilarity /= Double(queryNouns.count)
            if averageSimilarity <= self.DRAWING_THRESHOLD {
                log.info("Drawing similarity threshold achieved.")
                if !isMatch {
                    searchResult.note = note
                    isMatch = true
                }
            }
        }
        log.info("Analysis of note drawings: \(self.getCurrentTime() - time)ms")
        // MARK: Documents search
        time = self.getCurrentTime()
        var foundInDocuments = false
        for document in note.1.getDocuments() {
            // MARK: Document Description
            if let description = document.description {
                let words = self.tokenize(text: description, unit: .word)
                var averageSimilarity = 0.0
                for queryWord in queryWords {
                    var minimumSimilarity = 999.0
                    for word in words {
                        let similarity = wordEmbedding.distance(between: queryWord.lowercased(), and: word.lowercased(), distanceType: .cosine)
                        if similarity < minimumSimilarity {
                            minimumSimilarity = similarity
                        }
                    }
                    averageSimilarity += minimumSimilarity
                }
                averageSimilarity /= Double(queryWords.count)
                if averageSimilarity <= self.SEARCH_THRESHOLD {
                    log.info("Found in document: \(document.title)")
                    searchResult.documents.append(document)
                    foundInDocuments = true
                }
            }
            // MARK: Document Title
            let documentTitleWords = self.tokenize(text: document.title, unit: .word)
            var minimumDistance = 999.0
            var levenshteinMatchPercentage = 0.0
            for word in documentTitleWords {
                let distance = wordEmbedding.distance(between: query.lowercased(), and: word.lowercased())
                if distance == 2.0 { // Meaning: word is unknown to word embedder (has no vector representation)
                    let levenshteinDistance = query.lowercased().levenshtein(word.lowercased())
                    if levenshteinDistance == 0 {
                        levenshteinMatchPercentage = 1.0
                        break
                    }
                    else {
                        let temp = 1.0 / Double(levenshteinDistance)
                        if temp > levenshteinMatchPercentage {
                            levenshteinMatchPercentage = temp
                        }
                    }
                }
                if distance < minimumDistance {
                    minimumDistance = distance
                }
            }
            if minimumDistance <= self.KEYWORD_THRESHOLD || levenshteinMatchPercentage >= 0.75 {
                log.info("\(document.title) - \(minimumDistance)")
                log.info("Found query in title of document: \(document.title) [\(document.documentType.rawValue)]")
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
                    else if entity.1 == NLTag.personalName.rawValue {
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
                }
            }
        }
        if foundInDocuments && !isMatch {
            searchResult.note = note
        }
        log.info("Analysis of documents for note: \(self.getCurrentTime() - time)ms")
    }*/
    
    private func searchSentence(query: String, note: (URL, Note), queryNouns: [(String, String)], queryEntities: [(String, String)]) -> SearchResult {
        var searchResult = SearchResult()
        if let sentenceEmbedding = NLEmbedding.sentenceEmbedding(for: .english), let wordEmbedding = NLEmbedding.wordEmbedding(for: .english) {
            var isMatch = false
            // MARK: Body search
            let body = note.1.getText()
            let sentences = self.tokenize(text: body, unit: .sentence)
            var minimumSimilarity = 999.0
            for sentence in sentences {
                let similarity = sentenceEmbedding.distance(between: query, and: sentence, distanceType: .cosine)
                if similarity < minimumSimilarity {
                    minimumSimilarity = similarity
                }
            }
            if minimumSimilarity <= self.SEARCH_THRESHOLD {
                searchResult.note = note
                isMatch = true
                log.info("Minimum body similarity achieved: \(minimumSimilarity)")
            }
            
            // MARK: Drawings search
            if !isMatch {
                for term in queryNouns {
                    for drawing in note.1.getDrawingLabels() {
                        let similarity = wordEmbedding.distance(between: term.0, and: self.lemmatize(text: drawing))
                        log.info("\(term.0) - \(drawing): \(similarity)")
                        if similarity <= self.DRAWING_THRESHOLD {
                            log.info("Drawing similarity threshold achieved.")
                            if !isMatch {
                                searchResult.note = note
                                isMatch = true
                                break
                            }
                        }
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
                    let sentences = self.tokenize(text: description, unit: .sentence)
                    var minimumSimilarity = 999.0
                    for sentence in sentences {
                        let similarity = sentenceEmbedding.distance(between: query, and: sentence, distanceType: .cosine)
                        if similarity < minimumSimilarity {
                            minimumSimilarity = similarity
                        }
                    }
                    if minimumSimilarity <= self.SEARCH_THRESHOLD {
                        log.info("Found in document description of: \(document.title)")
                        searchResult.documents.append(document)
                        foundInDocuments = true
                    }
                }
                // MARK: Document Title
                let titleSimilarity = sentenceEmbedding.distance(between: document.title, and: query, distanceType: .cosine)
                if titleSimilarity <= self.SEARCH_THRESHOLD {
                    log.info("Found match in title of document: \(document.title)")
                    if !searchResult.documents.contains(document) {
                        searchResult.documents.append(document)
                        foundInDocuments = true
                    }
                }
                
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
    
    private enum PhraseType: String {
        case Keyword = "Keyword"
        case Clause = "Clause"
        case ExtendedClause = "Extended Clause"
        case Sentence = "Sentence"
    }
    
    private func checkPhraseType(queryPartsOfSpeech: [(String, String)]) -> PhraseType {
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
}

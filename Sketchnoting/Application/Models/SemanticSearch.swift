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
    static let SEARCH_THRESHOLD = 1.0
    static let DRAWING_THRESHOLD = 0.5
    
    static let entityExtractor = EntityExtractor.entityExtractor(options: EntityExtractorOptions(modelIdentifier:
                                                                                                    EntityExtractionModelIdentifier.english))
    static func downloadEntityExtractorModel() {
        entityExtractor.downloadModelIfNeeded(completion: { error in
            if error == nil {
                log.info("Entity extraction model is ready.")
            }
            else {
                log.error("Entity extraction model not available: \(error!)")
            }
        })
    }
    static func tokenize(text: String, unit: NLTokenUnit = .sentence) -> [String] {
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
    
    static func tag(text: String, scheme: NLTagScheme = .lexicalClass) -> [(String, String)] {
        let tagger = NLTagger(tagSchemes: [scheme])
        tagger.string = text
        let tags = tagger.tags(in: text.startIndex..<text.endIndex, unit: .word, scheme: scheme, options: [.omitPunctuation, .omitWhitespace])
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
    
    static func extractEntities(text: String, entityCompletion: (DateTimeEntity?) -> Void) {
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
    static var dateTimeEntity: DateTimeEntity?
    
    static func search(query: String, notes: [(URL, Note)]) {
        // missing: note tags
        let tagger = NLTagger(tagSchemes: [.lemma])
        if let sentenceEmbedding = NLEmbedding.sentenceEmbedding(for: .english), let wordEmbedding = NLEmbedding.wordEmbedding(for: .english) {
            let queryWords = tokenize(text: query, unit: .word)
            let queryPartsOfSpeech = tag(text: query, scheme: .lexicalClass)
            let queryEntities = tag(text: query, scheme: .nameType)
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
            
            var results = [(URL, Note)]()
            var documentResults = [Document]()
            var locationResults = [Document]()
            var personResults = [Document]()
            
            let queryType = checkPhraseType(queryPartsOfSpeech: queryPartsOfSpeech)
            // MARK: Keyword or Clause
            if queryType == .Keyword || queryType == .Clause {
                log.info("Performing semantic search on query of type: \(queryType.rawValue)")
                for note in notes {
                    log.info("- Searching note: \(note.1.getName())")
                    var found = false
                    // MARK: Body search
                    let body = note.1.getText()
                    let words = SemanticSearch.tokenize(text: body, unit: .word)
                    var averageSimilarity = 0.0
                    for queryWord in queryWords {
                        var minimumSimilarity = 999.0
                        var similarWord = ""
                        for word in words {
                            let similarity = sentenceEmbedding.distance(between: queryWord, and: word, distanceType: .cosine)
                            if similarWord.isEmpty {
                                similarWord = word
                            }
                            if similarity < minimumSimilarity {
                                minimumSimilarity = similarity
                                similarWord = word
                            }
                        }
                        averageSimilarity += minimumSimilarity
                    }
                    averageSimilarity /= Double(queryWords.count)
                    if averageSimilarity <= SEARCH_THRESHOLD {
                        results.append(note)
                        found = true
                        log.info("Body similarity threshold achieved: \(averageSimilarity)")
                    }
                    // MARK: Drawings search
                    averageSimilarity = 0.0
                    for term in queryNouns {
                        var minimumSimilarity = 999.0
                        for page in note.1.pages {
                            for drawing in page.getDrawingLabels() {
                                let similarity = wordEmbedding.distance(between: term.0, and: drawing)
                                log.info("\(term.0) - \(drawing): \(similarity)")
                                if similarity < minimumSimilarity {
                                    minimumSimilarity = similarity
                                }
                            }
                        }
                        averageSimilarity += minimumSimilarity
                    }
                    averageSimilarity /= Double(queryNouns.count)
                    if averageSimilarity <= DRAWING_THRESHOLD {
                        log.info("Drawing similarity threshold achieved.")
                        if !found {
                            results.append(note)
                            found = true
                        }
                    }
                    // MARK: Documents search
                    var foundInDocuments = false
                    for document in note.1.getDocuments() {
                        // MARK: Document Description
                        if let description = document.description {
                            let words = SemanticSearch.tokenize(text: description, unit: .word)
                            var averageSimilarity = 0.0
                            for queryWord in queryWords {
                                var minimumSimilarity = 999.0
                                var similarWord = ""
                                for word in words {
                                    let similarity = sentenceEmbedding.distance(between: queryWord, and: word, distanceType: .cosine)
                                    if similarWord.isEmpty {
                                        similarWord = word
                                    }
                                    if similarity < minimumSimilarity {
                                        minimumSimilarity = similarity
                                        similarWord = word
                                    }
                                }
                                averageSimilarity += minimumSimilarity
                            }
                            averageSimilarity /= Double(queryWords.count)
                            if averageSimilarity <= SEARCH_THRESHOLD {
                                log.info("Found in document: \(document.title)")
                                documentResults.append(document)
                                foundInDocuments = true
                            }
                        }
                        // MARK: Document Title
                        let similarity = sentenceEmbedding.distance(between: query, and: document.title, distanceType: .cosine)
                        if similarity <= SEARCH_THRESHOLD {
                            log.info("Found query in title of document: \(document.title)")
                            if !documentResults.contains(document) {
                                documentResults.append(document)
                                foundInDocuments = true
                            }
                        }
                        // MARK: Document entities - to adjust
                        if let tagmeDocument = document as? TAGMEDocument, let categories = tagmeDocument.categories {
                            var locationSynonyms = [String]()
                            locationSynonyms.append("location")
                            var synonyms = wordEmbedding.neighbors(for: "location", maximumCount: 5)
                            for syn in synonyms {
                                locationSynonyms.append(syn.0.lowercased())
                            }
                            var personSynonyms = [String]()
                            personSynonyms.append("person")
                            synonyms = wordEmbedding.neighbors(for: "person", maximumCount: 5)
                            for syn in synonyms {
                                personSynonyms.append(syn.0.lowercased())
                            }
                            for entity in queryEntities {
                                if entity.1 == NLTag.placeName.rawValue {
                                    var foundLocation = false
                                    for category in categories {
                                        for locationSynonym in locationSynonyms {
                                            let similarity = wordEmbedding.distance(between: category, and: locationSynonym, distanceType: .cosine)
                                            if similarity <= 1.0 {
                                                log.info("Found location related document: \(category) - \(locationSynonym)")
                                                foundLocation = true
                                                locationResults.append(document)
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
                                        for personSynonym in personSynonyms {
                                            let similarity = wordEmbedding.distance(between: category, and: personSynonym, distanceType: .cosine)
                                            if similarity <= 1.0 {
                                                log.info("Found person related document: \(category) - \(personSynonym)")
                                                foundPerson = true
                                                personResults.append(document)
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
                    if foundInDocuments && !found {
                        results.append(note)
                    }
                }
            }
            else { // ExtendedClause or Sentence
                
            }
            
            for note in notes {
                log.info("Searching note: \(note.1.getName())")
                var found = false
                // Body search
                let body = note.1.getText()
                let sentences = SemanticSearch.tokenize(text: body, unit: .sentence)
                var minimumSimilarity = 999.0
                var similarSentence = ""
                for sentence in sentences {
                    let similarity = sentenceEmbedding.distance(between: query, and: sentence, distanceType: .cosine)
                    if similarSentence.isEmpty {
                        similarSentence = sentence
                    }
                    if similarity < minimumSimilarity {
                        minimumSimilarity = similarity
                        similarSentence = sentence
                    }
                }
                if minimumSimilarity <= SEARCH_THRESHOLD {
                    results.append(note)
                    found = true
                    log.info("Minimum body similarity achieved: \(minimumSimilarity)")
                }
                
                // Drawings search
                for term in queryNouns {
                    for page in note.1.pages {
                        for drawing in page.getDrawingLabels() {
                            let similarity = wordEmbedding.distance(between: term.0, and: drawing)
                            log.info("\(term.0) - \(drawing): \(similarity)")
                            if similarity <= DRAWING_THRESHOLD {
                                if !found {
                                    results.append(note)
                                    found = true
                                }
                            }
                        }
                        if found {
                            break
                        }
                    }
                    if found {
                        break
                    }
                }
                // Documents search
                var foundInDocuments = false
                for document in note.1.getDocuments() {
                    // Description
                    if let description = document.description {
                        let sentences = SemanticSearch.tokenize(text: description, unit: .sentence)
                        var minimumSimilarity = 999.0
                        var similarSentence = ""
                        for sentence in sentences {
                            let similarity = sentenceEmbedding.distance(between: query, and: sentence, distanceType: .cosine)
                            if similarSentence.isEmpty {
                                similarSentence = sentence
                            }
                            if similarity < minimumSimilarity {
                                minimumSimilarity = similarity
                                similarSentence = sentence
                            }
                        }
                        if minimumSimilarity <= SEARCH_THRESHOLD {
                            log.info("Found in document: \(document.title)")
                            documentResults.append(document)
                            foundInDocuments = true
                        }
                    }
                    // Title
                    for term in queryNouns {
                        if document.title.lowercased().contains(term.0.lowercased()) {
                            log.info("Found noun '\(term.0)' in title of document: \(document.title)")
                            if !documentResults.contains(document) {
                                documentResults.append(document)
                                foundInDocuments = true
                            }
                            break
                        }
                    }
                    if let tagmeDocument = document as? TAGMEDocument, let categories = tagmeDocument.categories {
                        var locationSynonyms = [String]()
                        locationSynonyms.append("location")
                        var synonyms = wordEmbedding.neighbors(for: "location", maximumCount: 5)
                        for syn in synonyms {
                            locationSynonyms.append(syn.0.lowercased())
                        }
                        var personSynonyms = [String]()
                        personSynonyms.append("person")
                        synonyms = wordEmbedding.neighbors(for: "person", maximumCount: 5)
                        for syn in synonyms {
                            personSynonyms.append(syn.0.lowercased())
                        }
                        for entity in queryEntities {
                            if entity.1 == NLTag.placeName.rawValue {
                                var foundLocation = false
                                for category in categories {
                                    for locationSynonym in locationSynonyms {
                                        let similarity = wordEmbedding.distance(between: category, and: locationSynonym, distanceType: .cosine)
                                        if similarity <= 1.0 {
                                            log.info("Found location related document: \(category) - \(locationSynonym)")
                                            foundLocation = true
                                            locationResults.append(document)
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
                                    for personSynonym in personSynonyms {
                                        let similarity = wordEmbedding.distance(between: category, and: personSynonym, distanceType: .cosine)
                                        if similarity <= 1.0 {
                                            log.info("Found person related document: \(category) - \(personSynonym)")
                                            foundPerson = true
                                            personResults.append(document)
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
                if foundInDocuments && !found {
                    results.append(note)
                }
            }
        }
    }
    
    private enum PhraseType: String {
        case Keyword = "Keyword"
        case Clause = "Clause"
        case ExtendedClause = "Extended Clause"
        case Sentence = "Sentence"
    }
    
    private static func checkPhraseType(queryPartsOfSpeech: [(String, String)]) -> PhraseType {
        if queryPartsOfSpeech.count < 2 {
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

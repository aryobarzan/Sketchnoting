//
//  TextParser.swift
//  Sketchnoting
//
//  Created by Aryobarzan on 25/02/2021.
//  Copyright © 2021 Aryobarzan. All rights reserved.
//

import UIKit

class TextParser {
    
    static let shared = TextParser()
    private init(){}
    
    func clean(text: String) -> String {
        let spellchecker = UITextChecker()

        let sentences = SemanticSearch.shared.tokenize(text: text, unit: .sentence)
        var validSentences = [String]()
        for sentence in sentences {
            let words = SemanticSearch.shared.tokenize(text: sentence, unit: .word)
            var incorrectCount = 0
            for word in words {
                let range = NSRange(location: 0, length: word.utf16.count)
                let misspelledRange = spellchecker.rangeOfMisspelledWord(in: word, range: range, startingAt: 0, wrap: false, language: "en")
                if misspelledRange.location != NSNotFound {
                    incorrectCount += 1
                }
            }
            if incorrectCount < (words.count+1) / 2 {
                validSentences.append(sentence.trimmingCharacters(in: .whitespacesAndNewlines))
            }
            else {
                log.error("Invalid sentence: \(sentence)")
                continue
            }
            
            let partsOfSpeech = SemanticSearch.shared.tag(text: sentence, scheme: .lexicalClass)
            let phraseType = SemanticSearch.shared.checkPhraseType(queryPartsOfSpeech: partsOfSpeech)
            if phraseType == .Keyword || phraseType == .Clause {
                validSentences.removeLast()
                log.error("Invalid phrase type '\(phraseType.rawValue)' - \(sentence)")
                continue
            }
            let invalidCharacters = ["()", "[]", "{", "}"] //";"
            for invalidCharacter in invalidCharacters {
                if sentence.contains(invalidCharacter) {
                    validSentences.removeLast()
                    log.error("Invalid character '\(invalidCharacter)' - \(sentence)")
                    break
                }
            }
            if !validSentences.contains(sentence) {
                continue
            }
            if sentence.range(of: ".*for\\s\\(.*\\).*", options: .regularExpression, range: nil) != nil {
                validSentences.removeLast()
                log.error("Invalid pattern 'for ()' - \(sentence)")
                continue
            }
            if sentence.hasSuffix(";") {
                validSentences.removeLast()
                continue
            }
        }
        // Remove extra whitespaces
        for i in 0..<validSentences.count {
            validSentences[i] = validSentences[i].replacingOccurrences(of: "[\\s\n]+", with: " ", options: .regularExpression, range: nil)
        }
        log.info("Out of \(sentences.count) sentences, \(validSentences.count) are valid.")
        return validSentences.joined(separator: "\n")
    }
}

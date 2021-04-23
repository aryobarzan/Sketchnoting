//
//  TextParser.swift
//  Sketchnoting
//
//  Created by Aryobarzan on 25/02/2021.
//  Copyright © 2021 Aryobarzan. All rights reserved.
//

import UIKit
import NaturalLanguage
import SwiftCoroutine

class TextParser {
    
    static let shared = TextParser()
    private init(){}
    
    func clean(text: String) -> String {
        let spellchecker = UITextChecker()

        let sentences = SemanticSearch.shared.tokenize(text: text.trimmingCharacters(in: .whitespaces), unit: .sentence)
        var validSentences = [String]()
        for sentence in sentences {
            // 1
            let words = SemanticSearch.shared.tokenize(text: sentence.trimmingCharacters(in: .whitespaces), unit: .word)
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
                //logger.error("Invalid sentence: \(sentence)")
                continue
            }
            // 2
            let partsOfSpeech = SemanticSearch.shared.tag(text: sentence.trimmingCharacters(in: .whitespaces), scheme: .lexicalClass)
            let phraseType = SemanticSearch.shared.checkPhraseType(queryPartsOfSpeech: partsOfSpeech)
            if (phraseType == .Keyword && !partsOfSpeech.isEmpty && partsOfSpeech[0].1 != NLTag.noun) {
                validSentences.removeLast()
                //logger.error("Invalid phrase type '\(phraseType.rawValue)' - \(sentence)")
                continue
            }
            // 3
            var invalid = false
            let invalidCharacters = ["()", "[]", "{", "}"] //";"
            for invalidCharacter in invalidCharacters {
                if sentence.contains(invalidCharacter) {
                    invalid = true
                    validSentences.removeLast()
                    //logger.error("Invalid character '\(invalidCharacter)' - \(sentence)")
                    break
                }
            }
            if invalid {
                continue
            }
            // 4
            if sentence.range(of: ".*for\\s\\(.*\\).*", options: .regularExpression, range: nil) != nil {
                validSentences.removeLast()
                //logger.error("Invalid pattern 'for ()' - \(sentence)")
                continue
            }
            // 5
            if sentence.hasSuffix(";") {
                validSentences.removeLast()
                continue
            }
        }
        // Remove extra whitespaces
        let finalText = validSentences.map{ !($0.hasSuffix(".") || $0.hasSuffix("?") || $0.hasSuffix("!")) ? $0 + "." : $0 }
            .joined(separator: " ").replacingOccurrences(of: "[\\s\n]+", with: " ", options: .regularExpression, range: nil)
        //logger.info("Out of \(Int(sentences.count)) sentences, \(Int(validSentences.count)) are valid.")
        return finalText
    }
}

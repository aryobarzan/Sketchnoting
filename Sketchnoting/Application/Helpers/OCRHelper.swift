//
//  OCRHelper.swift
//  Sketchnoting
//
//  Created by Aryobarzan on 15/03/2019.
//  Copyright © 2019 Aryobarzan. All rights reserved.
//

import Foundation
import GPUImage

class OCRHelper {
    
    // Text checker
    private static var textChecker = UITextChecker()
    
    static func postprocess(text: String) -> String {
        let firstRun = spellcheckManually(original: text)
        print("First run: " + firstRun)
        let secondRun = spellcheckAutomatically(original: firstRun)
        print("Second run: " + secondRun)
        return secondRun
    }
    
    private static func spellcheckManually(original: String) -> String {
        var text = original.replacingOccurrences(of: "\n", with: " ")
        var words = text.components(separatedBy: " ")
        var index = 0
        for word in words {
            if word.count >= 2 && containsLetter(input: word) && containsSpecialSymbolOrNumber(input: word) {
                let misspelledRange =
                    textChecker.rangeOfMisspelledWord(in: text,
                                                      range: NSRange(text.index(of: word)!.encodedOffset..<text.endIndex(of: word)!.encodedOffset),
                                                      startingAt: 0,
                                                      wrap: false,
                                                      language: "en_US")
                
                if misspelledRange.location != NSNotFound,
                    let guesses = textChecker.guesses(forWordRange: misspelledRange,
                                                      in: text,
                                                      language: "en_US")
                {
                    if guesses.count > 0 {
                        words[index] = guesses.first!
                        text = words.joined(separator: " ")
                    }
                }
                index = index + 1
            }
            
        }
        return words.joined(separator: " ")
    }
    private static func containsLetter(input: String) -> Bool {
        for chr in input.lowercased() {
            if (chr >= "a" && chr <= "z") {
                return true
            }
        }
        return false
    }
    private static func containsSpecialSymbolOrNumber(input: String) -> Bool {
        var count = 0
        for chr in input.lowercased() {
            if (chr >= "a" && chr <= "z"){
                count += 1
            }
        }
        if count == input.count {
            return false
        }
        return true
    }
    private static func spellcheckAutomatically(original: String) -> String {
        var text = original.replacingOccurrences(of: "\n", with: " ")
        var words = text.components(separatedBy: " ")
        var index = 0
        for word in words {
            let misspelledRange =
                textChecker.rangeOfMisspelledWord(in: text,
                                                  range: NSRange(text.index(of: word)!.encodedOffset..<text.endIndex(of: word)!.encodedOffset),
                                                  startingAt: 0,
                                                  wrap: false,
                                                  language: "en_US")
            
            if misspelledRange.location != NSNotFound,
                let guesses = textChecker.guesses(forWordRange: misspelledRange,
                                                  in: text,
                                                  language: "en_US")
            {
                if guesses.count > 0 {
                    words[index] = guesses.first!
                    text = words.joined(separator: " ")
                }
            }
            index = index + 1
        }
        return words.joined(separator: " ")
    }
}

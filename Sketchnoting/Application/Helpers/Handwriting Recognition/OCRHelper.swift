//
//  OCRHelper.swift
//  Sketchnoting
//
//  Created by Aryobarzan on 15/03/2019.
//  Copyright © 2019 Aryobarzan. All rights reserved.
//

import Foundation
import GPUImage

// This file contains the post-processing functions for the handwriting recognition (OCR)
// The post-processing simply uses iOS' in-built spell checker to correct the recognized text
// Any word recognized as syntactically wrong by the spell checker is replaced by the first best guess (suggestion) made by the same spell checker, if it has any guesses

class OCRHelper {
    
    // Spellchecking
    private static var textChecker = UITextChecker()
    
    static func postprocess(text: String) -> String {
        let spellchecked = spellcheckAutomatically(original: text)
        return spellchecked
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

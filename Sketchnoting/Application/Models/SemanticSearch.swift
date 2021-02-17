//
//  SemanticSearch.swift
//  Sketchnoting
//
//  Created by Aryobarzan on 17/02/2021.
//  Copyright © 2021 Aryobarzan. All rights reserved.
//

import Foundation
import NaturalLanguage

class SemanticSearch {
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
}

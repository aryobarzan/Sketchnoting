/**
 This file is part of the Reductio package.
 (c) Sergio Fernández <fdz.sergio@gmail.com>
 For the full copyright and license information, please view the LICENSE
 file that was distributed with this source code.
 */

import Foundation
import NaturalLanguage

internal struct Stemmer {

    static func stemmingWordsInText(_ text: String) -> [String] {
        var stems: [String] = []
        
        let tagOptions: NLTagger.Options = [.omitWhitespace, .omitPunctuation, .omitOther]
        let tagSchemes = NLTagger.availableTagSchemes(for: .word, language: .english)
        let tagger = NLTagger(tagSchemes: tagSchemes)
        tagger.string = text
        tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word,
                             scheme: .lemma,
                             options: tagOptions) { (tag, tokenRange) in
            let token = text[tokenRange]
            if !token.isEmpty {
                stems.append(token.lowercased())
            }
            return true
        }
        return stems
    }
}

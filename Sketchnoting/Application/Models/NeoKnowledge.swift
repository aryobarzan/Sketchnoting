//
//  NeoKnowledge.swift
//  Sketchnoting
//
//  Created by Aryobarzan on 19/03/2021.
//  Copyright © 2021 Aryobarzan. All rights reserved.
//

import UIKit

class NeoKnowledge {
    static let shared = NeoKnowledge()
    private init() {}
    
    private var note_TFIDF = [String : [Double]]()
    
    func index(noteIterator: NoteIterator) {
        var noteIterator = noteIterator
        
        var noteBags = [String : [String]]()
        var noteTFs = [String : [String : Double]]()
        var wordIDFs = [String : Double]()
        var N = 0
        var uniqueWords = [String]()
        
        while let note = noteIterator.next() {
            N += 1
            // Lowercase, lemmatize & remove stopwords
            var words = SemanticSearch.shared.tokenize(text: note.1.getName(), unit: .word) +  SemanticSearch.shared.tokenize(text: note.1.getText(option: .FullText, parse: true), unit: .word)
            words = words.map { SemanticSearch.shared.lemmatize(text: $0.lowercased()) }
            words = words.filter { !stopwords.contains($0) }
            
            noteBags[note.1.getID()] = words
            uniqueWords += words
        }
        uniqueWords = Array(Set(uniqueWords))
        
        noteIterator.reset()
        
        while let note = noteIterator.next() {
            let noteBag = noteBags[note.1.getID()]!
            var counts = noteBag.reduce(into: [:]) { counts, word in counts[word, default: 0.0] += 1.0 }
            for (key, value) in counts {
                counts[key] = value / (Array(counts.values).reduce(0, +))
            }
            var dict = [String : Double]()
            for word in uniqueWords {
                if counts[word] == nil {
                    dict[word] = 0.0
                }
                else {
                    dict[word] = counts[word]
                }
            }
            noteTFs[note.1.getID()] = dict
        }
        
        for word in uniqueWords {
            var count: Double = 0.0
            for (_, value) in noteBags {
                if value.contains(word) {
                    count += 1.0
                }
            }
            wordIDFs[word] = Double(N) / count
        }
        
        for (key, value) in noteTFs {
            var vector = [Double](repeating: 0.0, count: uniqueWords.count)
            for i in 0..<uniqueWords.count {
                vector[i] = value[uniqueWords[i]]! * wordIDFs[uniqueWords[i]]!
            }
            note_TFIDF[key] = vector
        }
        logger.info(uniqueWords.count)
    }
    
    func getTFIDF(for note: Note) -> [Double] {
        return note_TFIDF[note.getID()]!
    }
}

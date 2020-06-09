//
//  Knowledge.swift
//  Sketchnoting
//
//  Created by Aryobarzan on 20/12/2019.
//  Copyright © 2019 Aryobarzan. All rights reserved.
//

import UIKit

class Knowledge {
    static var tf_idfs: Dictionary<Note, Dictionary<String, Float>>?
    public static func setupSimilarityMatrix() {
        tf_idfs = Dictionary<Note, Dictionary<String, Float>>()
        var termBags = Dictionary<Note, [String]>()
        var termFrequencies = Dictionary<Note, Dictionary<String, Int>>()
        var termTFs = Dictionary<Note, Dictionary<String, Float>>()
        var termIDFs = Dictionary<String, Float>()
        var uniqueTerms = [String]()
        
        for note in DataManager.notes {
            var bag = [String]()
            bag = note.getText().components(separatedBy: " ")
            for t in note.getName().components(separatedBy: " ") {
                if !bag.contains(t) {
                    bag.append(t)
                }
            }
            for d in note.getDocuments() {
                for t in d.title.components(separatedBy: " ") {
                    if !bag.contains(t) {
                        bag.append(t)
                    }
                }
            }
            bag = bag.map {$0.lowercased()}
            termBags[note] = bag
            uniqueTerms = uniqueTerms + bag
            uniqueTerms = Array(Set(uniqueTerms))
        }
        for note in DataManager.notes {
            var frequencies = Dictionary<String, Int>()
            for t in uniqueTerms {
                frequencies[t] = 0
            }
            if let bag = termBags[note] {
                for t in bag {
                    if uniqueTerms.contains(t) {
                        frequencies[t] = frequencies[t]! + 1
                    }
                }
            }
            termFrequencies[note] = frequencies
        }
        for note in DataManager.notes {
            var tfs = Dictionary<String, Float>()
            if let bag = termBags[note] {
                for (t, c) in termFrequencies[note]! {
                    tfs[t] = Float(c) / Float(bag.count)
                }
            }
            termTFs[note] = tfs
        }
        for t in uniqueTerms {
            termIDFs[t] = Float(0)
        }
        for note in DataManager.notes {
            for t in uniqueTerms {
                if termBags[note]!.contains(t) {
                    termIDFs[t] = termIDFs[t]! + 1
                }
            }
        }
        let N = Float(DataManager.notes.count)
         for (t, f) in termIDFs {
            let division = N / f
            termIDFs[t] = log10(division)
        }
        for note in DataManager.notes {
            var noteIDFs = Dictionary<String, Float>()
            for (t, f) in termTFs[note]! {
                noteIDFs[t] = f * termIDFs[t]!
            }
            tf_idfs![note] = noteIDFs
        }
        log.info("Setup similarity matrix.")
    }
    
    static func similarNotesFor(note: Note) -> [(Note, Float)] {
        var similarNotes = [Note : Float]()
        for n in DataManager.notes {
            if n != note {
                similarNotes[n] = self.calculateTFIDFSimilarity(n1: note, n2: n)
            }
        }
        let similarNotesSorted = similarNotes.sorted{$0.1 < $1.1}
        return similarNotesSorted
    }
    
    private static func calculateTFIDFSimilarity(n1: Note, n2: Note) -> Float {
        var score = Float(0)
        for t in tf_idfs![n1]!.keys {
            score = score + (tf_idfs![n1]![t]! * tf_idfs![n2]![t]!)
        }
        return score
    }
}

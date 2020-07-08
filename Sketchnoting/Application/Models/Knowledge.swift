//
//  Knowledge.swift
//  Sketchnoting
//
//  Created by Aryobarzan on 20/12/2019.
//  Copyright © 2019 Aryobarzan. All rights reserved.
//

import UIKit

class Knowledge {
    // to update: fetch all notes, not just in the current folder
    static var tf_idfs: Dictionary<URL, (Note, Dictionary<String, Float>)>?
    public static func setupSimilarityMatrix() {
        tf_idfs = Dictionary<URL, (Note, Dictionary<String, Float>)>()
        var termBags = Dictionary<URL, (Note, [String])>()
        var termFrequencies = Dictionary<URL, (Note, Dictionary<String, Int>)>()
        var termTFs = Dictionary<URL, (Note, Dictionary<String, Float>)>()
        var termIDFs = Dictionary<String, Float>()
        var uniqueTerms = [String]()
        
        let allNotes = NeoLibrary.getNotes()
        
        for note in allNotes {
            var bag = [String]()
            bag = note.1.getText().components(separatedBy: " ")
            for t in note.1.getName().components(separatedBy: " ") {
                if !bag.contains(t) {
                    bag.append(t)
                }
            }
            for d in note.1.getDocuments() {
                for t in d.title.components(separatedBy: " ") {
                    if !bag.contains(t) {
                        bag.append(t)
                    }
                }
            }
            bag = bag.map {$0.lowercased()}
            termBags[note.0] = (note.1, bag)
            uniqueTerms = uniqueTerms + bag
            uniqueTerms = Array(Set(uniqueTerms))
        }
        for note in allNotes {
            var frequencies = Dictionary<String, Int>()
            for t in uniqueTerms {
                frequencies[t] = 0
            }
            if let bag = termBags[note.0] {
                for t in bag.1 {
                    if uniqueTerms.contains(t) {
                        frequencies[t] = frequencies[t]! + 1
                    }
                }
            }
            termFrequencies[note.0] = (note.1, frequencies)
        }
        for note in allNotes {
            var tfs = Dictionary<String, Float>()
            if let bag = termBags[note.0] {
                for (t, c) in termFrequencies[note.0]!.1 {
                    tfs[t] = Float(c) / Float(bag.1.count)
                }
            }
            termTFs[note.0] = (note.1, tfs)
        }
        for t in uniqueTerms {
            termIDFs[t] = Float(0)
        }
        for note in allNotes {
            for t in uniqueTerms {
                if termBags[note.0]!.1.contains(t) {
                    termIDFs[t] = termIDFs[t]! + 1
                }
            }
        }
        let N = Float(allNotes.count)
         for (t, f) in termIDFs {
            let division = N / f
            termIDFs[t] = log10(division)
        }
        for note in allNotes {
            var noteIDFs = Dictionary<String, Float>()
            for (t, f) in termTFs[note.0]!.1 {
                noteIDFs[t] = f * termIDFs[t]!
            }
            tf_idfs![note.0] = (note.1, noteIDFs)
        }
        log.info("Setup of similarity matrix complete.")
    }
    
    static func similarNotesFor(url: URL, note: Note) -> [(URL, Note, Float)] {
        var similarNotes = [(URL, Note, Float)]()
        for n in NeoLibrary.getNotes() {
            if n.0 != url {
                similarNotes.append((url, note, self.calculateTFIDFSimilarity(n1: url, n2: n.0)))
            }
        }
        let similarNotesSorted = similarNotes.sorted{$0.2 < $1.2}
        return similarNotesSorted
    }
    
    private static func calculateTFIDFSimilarity(n1: URL, n2: URL) -> Float {
        var score = Float(0)
        for t in tf_idfs![n1]!.1.keys {
            score = score + (tf_idfs![n1]!.1[t]! * tf_idfs![n2]!.1[t]!)
        }
        return score
    }
}

//
//  Knowledge.swift
//  Sketchnoting
//
//  Created by Aryobarzan on 20/12/2019.
//  Copyright © 2019 Aryobarzan. All rights reserved.
//

import UIKit
import SwiftGraph

class Knowledge {
    private static var similarNotesGraph = WeightedGraph<Sketchnote, Double>()
    
    public static func refreshSimilarNotesGraph() {
        similarNotesGraph = WeightedGraph<Sketchnote, Double>()
        // Initialize all nodes
        for note in NotesManager.notes {
            _ = similarNotesGraph.addVertex(note)
        }
        // Create edges with weight based on similarity
        for note in NotesManager.notes {
            var allNotes = NotesManager.notes
            allNotes.removeAll{$0 == note}
            for other in allNotes {
                let similarity = note.similarTo(note: other)
                if similarity > 0.0 {
                    similarNotesGraph.addEdge(from: note, to: other, weight: similarity)
                }
            }
        }
    }
    
    public static func getNotesSimilarTo(_ note: Sketchnote) -> [Sketchnote : Double]? {
        let edges = similarNotesGraph.edgesForVertex(note)
        if let edges = edges {
            if edges.count > 0 {
                var similarNotes = [Sketchnote : Double]()
                for edge in edges {
                    let n = getNote(edge.v)
                    if similarNotes[n] == nil {
                        similarNotes[n] = edge.weight
                    }
                }
                return similarNotes
            }
            return nil
        }
        return nil
    }
    
    public static func getNote(_ index: Int) -> Sketchnote {
        return similarNotesGraph.vertexAtIndex(index)
    }
    
    public static func getNotes(_ edges: [WeightedEdge<Double>]) -> [Sketchnote] {
        var notes = [Sketchnote]()
        for edge in edges {
            let n = similarNotesGraph.vertexAtIndex(edge.v)
            if !notes.contains(n) {
                notes.append(n)
            }
        }
        return notes
    }
    
    static var tf_idfs: Dictionary<Sketchnote, Dictionary<String, Float>>?
    public static func setupSimilarityMatrix() {
        tf_idfs = Dictionary<Sketchnote, Dictionary<String, Float>>()
        var termBags = Dictionary<Sketchnote, [String]>()
        var termFrequencies = Dictionary<Sketchnote, Dictionary<String, Int>>()
        var termTFs = Dictionary<Sketchnote, Dictionary<String, Float>>()
        var termIDFs = Dictionary<String, Float>()
        var uniqueTerms = [String]()
        
        for note in NotesManager.notes {
            var bag = [String]()
            bag = note.getText().components(separatedBy: " ")
            for t in note.getTitle().components(separatedBy: " ") {
                if !bag.contains(t) {
                    bag.append(t)
                }
            }
            for d in note.documents {
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
        for note in NotesManager.notes {
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
        for note in NotesManager.notes {
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
        for note in NotesManager.notes {
            for t in uniqueTerms {
                if termBags[note]!.contains(t) {
                    termIDFs[t] = termIDFs[t]! + 1
                }
            }
        }
        /*let N = Float(NotesManager.notes.count)
         for (t, f) in termIDFs {
            let division = N / f
            termIDFs[t] = log10(division)
        }*/
        for note in NotesManager.notes {
            var noteIDFs = Dictionary<String, Float>()
            for (t, f) in termTFs[note]! {
                noteIDFs[t] = f * termIDFs[t]!
            }
            tf_idfs![note] = noteIDFs
        }
        log.info("Setup similarity matrix.")
    }
    
    static func similarNotesFor(note: Sketchnote) -> [(Sketchnote, Float)] {
        var similarNotes = [Sketchnote : Float]()
        for n in NotesManager.notes {
            if n != note {
                similarNotes[n] = self.calculateTFIDFSimilarity(n1: note, n2: n)
            }
        }
        let similarNotesSorted = similarNotes.sorted{$0.1 < $1.1}
        return similarNotesSorted
    }
    
    private static func calculateTFIDFSimilarity(n1: Sketchnote, n2: Sketchnote) -> Float {
        var score = Float(0)
        for t in tf_idfs![n1]!.keys {
            score = score + (tf_idfs![n1]![t]! * tf_idfs![n2]![t]!)
        }
        return score
    }
}

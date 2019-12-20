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
}

//
//  NoteCollection.swift
//  Sketchnoting
//
//  Created by Aryobarzan on 25/03/2019.
//  Copyright © 2019 Aryobarzan. All rights reserved.
//

import UIKit
// A note collection contains sketchnotes and has a title property.
class NoteCollection: Codable, Equatable {
    
    var title: String
    var notes: [Sketchnote]
    
    static let DocumentsDirectory = FileManager().urls(for: .documentDirectory, in: .userDomainMask).first!
    static let ArchiveURL = DocumentsDirectory.appendingPathComponent("noteCollections")
    
    enum CodingKeys: String, CodingKey {
        case title
        case notes = "notes"
    }
    
    //MARK: Initialization
    
    init?(title: String?, notes: [Sketchnote]?) {
        self.title = title ?? "Untitled"
        self.notes = notes ?? [Sketchnote]()
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(title, forKey: .title)
        try container.encode(notes, forKey: .notes)
    }
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        title = try container.decode(String.self, forKey: .title)
        notes = try container.decode([Sketchnote].self, forKey: .notes)
    }
    
    func addSketchnote(note: Sketchnote) {
        var exists = false
        for n in notes {
            if n.creationDate == note.creationDate {
                exists = true
                break
            }
        }
        if !exists {
            notes.append(note)
        }
    }
    
    func removeSketchnote(note: Sketchnote) {
        var toDeleteIndex = -1
        for i in 0..<notes.count {
            if notes[i].creationDate == note.creationDate {
                toDeleteIndex = i
                break
            }
        }
        if toDeleteIndex != -1 {
            self.notes.remove(at: toDeleteIndex)
        }
    }
    
    // The equality function is overriden to be able to properly compare 2 note collections with each other to check if they are equal or not.
    // A unique identifier is not generated for a note collection. Instead, the title and all of the contained notes are used together as an identifier.
    // This cannot lead to possible identifier conflicts, as a sketchnote is always added to a single note collection and cannot be part of multiple note collections.
    // A sketchnote itself has a unique identifier generated, which is explained in the Sketchnote.swift file
    static func == (lhs: NoteCollection, rhs: NoteCollection) -> Bool {
        if lhs.title == rhs.title && lhs.notes == rhs.notes {
            return true
        }
        return false
    }
}

//
//  NoteCollection.swift
//  Sketchnoting
//
//  Created by Aryobarzan on 25/03/2019.
//  Copyright © 2019 Aryobarzan. All rights reserved.
//

import UIKit

class NoteCollection: Codable, Equatable {
    
    var id: String
    var title: String
    var notes: [Sketchnote]
    
    enum CodingKeys: String, CodingKey {
        case id
        case title
        case notes = "notes"
    }
    
    //MARK: Initialization
    init?(title: String?, notes: [Sketchnote]?) {
        self.id = UUID().uuidString
        self.title = title ?? "Untitled"
        self.notes = notes ?? [Sketchnote]()
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        var noteIDs = [String]()
        for note in notes {
            noteIDs.append(note.id)
        }
        try container.encode(noteIDs, forKey: .notes)
    }
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        let noteIDs = try container.decode([String].self, forKey: .notes)
        notes = [Sketchnote]()
        for id in noteIDs {
            if let note = NoteLoader.loadSketchnote(id: id) {
                notes.append(note)
            }
        }
    }
    
    public func save() {
        let encoder = JSONEncoder()
        
        if let encoded = try? encoder.encode(self) {
            UserDefaults.collections.set(encoded, forKey: self.id)
            print("Note Collection " + id + " saved.")
        }
        else {
            print("Encoding failed for note collection " + id + ".")
        }
    }
    
    func addSketchnote(note: Sketchnote) {
        var exists = false
        for n in notes {
            if n.id == note.id {
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
            if notes[i].id == note.id {
                toDeleteIndex = i
                break
            }
        }
        if toDeleteIndex != -1 {
            self.notes.remove(at: toDeleteIndex)
        }
    }
    
    static func == (lhs: NoteCollection, rhs: NoteCollection) -> Bool {
        if lhs.id == rhs.id {
            return true
        }
        return false
    }
}

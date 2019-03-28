//
//  NoteCollection.swift
//  Sketchnoting
//
//  Created by Aryobarzan on 25/03/2019.
//  Copyright © 2019 Aryobarzan. All rights reserved.
//

import UIKit

class NoteCollection: Codable {
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
}

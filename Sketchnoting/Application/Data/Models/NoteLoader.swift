//
//  NoteLoader.swift
//  Sketchnoting
//
//  Created by Aryobarzan on 23/07/2019.
//  Copyright © 2019 Aryobarzan. All rights reserved.
//

import UIKit

class NoteLoader {
    public static func loadSketchnotes() -> [Sketchnote]? {
        let decoder = JSONDecoder()
        
        var sketchnotes = [Sketchnote]()
        for (key, _) in UserDefaults.sketchnotes.dictionaryRepresentation() {
            if let data = UserDefaults.sketchnotes.data(forKey: key),
                let loadedSketchnote = try? decoder.decode(Sketchnote.self, from: data) {
                print("Note " + key + " loaded.")
                sketchnotes.append(loadedSketchnote)
            }
        }
        return sketchnotes
    }
    public static func loadSketchnote(id: String) -> Sketchnote? {
        let decoder = JSONDecoder()
        
        var sketchnote: Sketchnote?
        if let data = UserDefaults.sketchnotes.data(forKey: id), let loadedSketchnote = try? decoder.decode(Sketchnote.self, from: data) {
            sketchnote = loadedSketchnote
            print("Note " + id + " loaded.")
        }
        return sketchnote
    }
    public static func loadCollections() -> [NoteCollection]? {
        let decoder = JSONDecoder()
        
        var collections = [NoteCollection]()
        for (key, _) in UserDefaults.collections.dictionaryRepresentation() {
            if let data = UserDefaults.collections.data(forKey: key),
                let loadedCollection = try? decoder.decode(NoteCollection.self, from: data) {
                print("Note Collection " + key + " loaded.")
                collections.append(loadedCollection)
            }
        }
        return collections
    }
    
    public static func delete(note: Sketchnote) {
        do {
            let DocumentsDirectory = FileManager().urls(for: .documentDirectory, in: .userDomainMask).first!
            let ArchiveURLPathArray = DocumentsDirectory.appendingPathComponent("NotePaths-" + note.id)
            try FileManager().removeItem(atPath: ArchiveURLPathArray.absoluteString)
        } catch {
        }
        UserDefaults.sketchnotes.removeObject(forKey: note.id)
    }
    public static func delete(collection: NoteCollection) {
        UserDefaults.collections.removeObject(forKey: collection.id)
    }
}

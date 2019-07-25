//
//  NotesManager.swift
//  Sketchnoting
//
//  Created by Aryobarzan on 28/05/2019.
//  Copyright © 2019 Aryobarzan. All rights reserved.
//

import UIKit

class NotesManager {

    static let shared = NotesManager()
    
    public var noteCollections = [NoteCollection]()
    private init() {
        if let savedNoteCollections = NoteLoader.loadCollections() {
            self.noteCollections += savedNoteCollections
        }
    }
    
    // MARK : Saving to and loading from disk
    private func saveNoteCollections() {
        for collection in noteCollections {
            collection.save()
        }
    }
    private func saveNotes() {
        for collection in noteCollections {
            for note in collection.notes {
                note.save()
            }
        }
    }
    
    // MARK : Updating data
    public func delete(noteCollection: NoteCollection) {
        var index = -1
        for i in 0..<self.noteCollections.count {
            if self.noteCollections[i] == noteCollection {
                index = i
                break
            }
        }
        if index != -1 {
            noteCollections[index].delete()
            self.noteCollections.remove(at: index)
        }
    }
    
    public func delete(noteCollection: NoteCollection, note: Sketchnote) {
        note.delete()
        noteCollection.removeSketchnote(note: note)
    }
    
    public func update(note: Sketchnote, pathArray: NSMutableArray?) {
        note.paths = pathArray
        note.save()
    }
    
    public func updateTitle(noteCollection: NoteCollection) {
        for collection in noteCollections {
            if collection == noteCollection {
                collection.title = noteCollection.title
                collection.save()
                break
            }
        }
    }
    
    public func add(noteCollection: NoteCollection) {
        self.noteCollections.append(noteCollection)
        noteCollection.save()
    }
}

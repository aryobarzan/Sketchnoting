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
    
    // This property holds the user's note collections.
    public var noteCollections = [NoteCollection]()
    // (!) This property maps the identifier (TimeInterval) of a sketchnote to its array of strokes drawn on its canvas.
    // As explained in the Sketchnote.swift file, the strokes drawn on a note's canvas are saved separately, as the strokes conform to a different encoding protocol.
    // Thus, when opening a sketchnote for editing, its identifier is used to retrieve its corresponing strokes (NSMutableArray) in this dictionary.
    public var pathArrayDictionary = [TimeInterval: NSMutableArray]()
    
    private init() {
        // The application attempts to load saved note collections from the device's disk here.
        // If any could be loaded, these are consequently displayed on the home page.
        if let savedNoteCollections = loadNoteCollections() {
            self.noteCollections += savedNoteCollections
        }
        // This loads the strokes array for each sketchnote saved to the device's disk.
        // See Sketchnote.swift file for more information as to why a sketchnote and the strokes on its canvas are stored separately
        if let savedPathArrayDictionary = loadPathArrayDictionary() {
            self.pathArrayDictionary = savedPathArrayDictionary
        }
    }
    
    // MARK : Saving to and loading from disk
    
    // Function used to save note collections to the device's disk for persistence.
    private func saveNoteCollections() {
        let encoder = JSONEncoder()
        
        if let encoded = try? encoder.encode(noteCollections) {
            UserDefaults.standard.set(encoded, forKey: "NoteCollections")
            print("Note Collections saved.")
        }
        else {
            print("Encoding failed for note collections")
        }
    }
    
    // Function used to save the strokes for each sketchnote as an entire dictionary to the device's disk for peristence.
    private func savePathArrayDictionary() {
        let DocumentsDirectory = FileManager().urls(for: .documentDirectory, in: .userDomainMask).first!
        let ArchiveURLPathArray = DocumentsDirectory.appendingPathComponent("PathArrayDictionary")
        if let encoded = try? NSKeyedArchiver.archivedData(withRootObject: self.pathArrayDictionary, requiringSecureCoding: false) {
            try! encoded.write(to: ArchiveURLPathArray)
            print("Path Array Dictionary saved.")
        }
        else {
            print("Failed to encode path array dictionary.")
        }
    }
    
    // Consequently, this function is used to reload the dictionary (saved in the previous function) from the device's disk.
    private func loadPathArrayDictionary() -> [TimeInterval: NSMutableArray]? {
        let DocumentsDirectory = FileManager().urls(for: .documentDirectory, in: .userDomainMask).first!
        let ArchiveURLPathArray = DocumentsDirectory.appendingPathComponent("PathArrayDictionary")
        guard let codedData = try? Data(contentsOf: ArchiveURLPathArray) else { return nil }
        guard let data = ((try? NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(codedData) as?
            [TimeInterval: NSMutableArray]) as [TimeInterval : NSMutableArray]??) else { return nil }
        print("Path Array Dictionary loaded.")
        return data
    }
    
    // This function reloads saved note collections from the device's disk.
    private func loadNoteCollections() -> [NoteCollection]? {
        let decoder = JSONDecoder()
        
        if let data = UserDefaults.standard.data(forKey: "NoteCollections"),
            let loadedNoteCollections = try? decoder.decode([NoteCollection].self, from: data) {
            print("Note Collections loaded")
            return loadedNoteCollections
        }
        print("Failed to load note collections.")
        return nil
    }
    
    // MARK : Access and usage of data
    public func delete(noteCollection: NoteCollection) {
        var index = -1
        for i in 0..<self.noteCollections.count {
            if self.noteCollections[i] == noteCollection {
                index = i
                break
            }
        }
        if index != -1 {
            print("Deleted note collection.")
            self.noteCollections.remove(at: index)
            self.saveNoteCollections()
        }
    }
    public func delete(noteCollection: NoteCollection, note: Sketchnote) {
        noteCollection.removeSketchnote(note: note)
        self.saveNoteCollections()
        print("Note deleted from note collection.")
    }
    
    public func update(note: Sketchnote, pathArray: NSMutableArray?) {
        for i in 0..<noteCollections.count {
            for j in 0..<noteCollections[i].notes.count {
                if noteCollections[i].notes[j] == note {
                    noteCollections[i].notes[j] = note
                    self.saveNoteCollections()
                    self.pathArrayDictionary[note.creationDate.timeIntervalSince1970] = pathArray
                    self.savePathArrayDictionary()
                    break
                }
            }
        }
    }
    public func updateTitle(noteCollection: NoteCollection) {
        for collection in noteCollections {
            if collection == noteCollection {
                collection.title = noteCollection.title
                self.saveNoteCollections()
                break
            }
        }
    }
    
    public func add(noteCollection: NoteCollection) {
        self.noteCollections.append(noteCollection)
        self.saveNoteCollections()
    }
    public func add(note: Sketchnote, pathArray: NSMutableArray?) {
        self.pathArrayDictionary[note.creationDate.timeIntervalSince1970] = pathArray
        self.savePathArrayDictionary()
    }
}

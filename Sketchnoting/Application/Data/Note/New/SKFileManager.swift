//
//  FileManager.swift
//  Sketchnoting
//
//  Created by Aryobarzan on 07/02/2020.
//  Copyright © 2020 Aryobarzan. All rights reserved.
//

import UIKit

import Kingfisher

class SKFileManager {
    static var currentFolder: Folder?
    static var currentFoldersHierarchy = [Folder]()
    static var folders = loadFolders()
    static var notes = loadNotes()
    static var activeNote: NoteX?
    
    static var receivedNotesController = ReceivedNotesController()
    
    private static let serializationQueue = DispatchQueue(label: "SerializationQueue", qos: .background)
    public static func getNotesDirectory() -> URL {
        let documentsPath = NSURL(fileURLWithPath: NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0])
        let logsPath = documentsPath.appendingPathComponent("SK-Notes")
        do
        {
            if !FileManager.default.fileExists(atPath: logsPath!.path) {
                try FileManager.default.createDirectory(atPath: logsPath!.path, withIntermediateDirectories: true, attributes: nil)
            }
            return logsPath!
        }
        catch let error as NSError
        {
            NSLog("Unable to create directory \(error.debugDescription)")
        }
        return logsPath!
    }
    public static func getFoldersDirectory() -> URL {
        let documentsPath = NSURL(fileURLWithPath: NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0])
        let logsPath = documentsPath.appendingPathComponent("SK-Folders")
        do
        {
            if !FileManager.default.fileExists(atPath: logsPath!.path) {
                try FileManager.default.createDirectory(atPath: logsPath!.path, withIntermediateDirectories: true, attributes: nil)
            }
            return logsPath!
        }
        catch let error as NSError
        {
            NSLog("Unable to create directory \(error.debugDescription)")
        }
        return logsPath!
    }
    
    public static func save(file: File) {
        serializationQueue.async {
            if let note = file as? NoteX {
                if let encoded = file.encodeFileAsData() {
                    try? encoded.write(to: self.getNotesDirectory().appendingPathComponent(file.id + ".sketchnote"))
                    log.info("Note \(note.getName()) saved.")
                }
                
            }
            else if let folder = file as? Folder {
                if let encoded = file.encodeFileAsData() {
                    try? encoded.write(to: self.getFoldersDirectory().appendingPathComponent(file.id))
                    log.info("Folder \(folder.getName()) saved.")
                }
                
            }
        }
    }
    
    private static func loadNotes() -> [NoteX] {
        var notes = [NoteX]()
        do {
            let fileURLs = try FileManager.default.contentsOfDirectory(at: getNotesDirectory(), includingPropertiesForKeys: nil)
            for url in fileURLs {
                do {
                    let data = try Data(contentsOf: url)
                    if let decodedNote = self.decodeNoteFromData(data: data) {
                        notes.append(decodedNote)
                    }
                } catch {
                    log.error("Failed to load note.")
                }
            }
        } catch {
            log.error("Error while enumerating files \(getNotesDirectory().path): \(error.localizedDescription)")
        }
        return notes
    }
    private static func loadFolders() -> [Folder] {
        var folders = [Folder]()
        do {
            let fileURLs = try FileManager.default.contentsOfDirectory(at: getFoldersDirectory(), includingPropertiesForKeys: nil)
            for url in fileURLs {
                do {
                    let data = try Data(contentsOf: url)
                    if let decodedFolder = self.decodeFolderFromData(data: data) {
                        folders.append(decodedFolder)
                    }
                } catch {
                    log.error("Failed to load folder.")
                }
            }
        } catch {
            log.error("Error while enumerating files \(getFoldersDirectory().path): \(error.localizedDescription)")
        }
        return folders
    }
    
    public static func getCurrentFiles() -> [File] {
        var files = [File]()
        for n in notes {
            if n.parent == self.currentFolder?.id {
                files.append(n)
                log.info("Retrieved note: \(n.id)")
            }
        }
        for f in folders {
            if f.parent == self.currentFolder?.id {
                files.append(f)
                log.info("Retrieved folder: \(f.id)")
            }
        }
        return files
    }
    
    public static func delete(file: File) {
        var path = self.getNotesDirectory()
        if file is NoteX {
            path = self.getNotesDirectory().appendingPathComponent(file.id + ".sketchnote")
        }
        else if file is Folder {
            path = self.getFoldersDirectory().appendingPathComponent(file.id)
        }
        let noteURL = self.getNotesDirectory().appendingPathComponent(file.id + ".sketchnote")
        if FileManager.default.fileExists(atPath: path.path) {
            try? FileManager.default.removeItem(atPath: noteURL.path)
        }
        log.info("Deleted note.")

        if file.parent != nil {
            if let parentFolder = getFolder(id: file.parent!) {
                parentFolder.removeChild(file: file)
                self.save(file: parentFolder)
            }
        }
        
        if let folder = file as? Folder {
            for c in folder.getChildren() {
                if let n = getNote(id: c) {
                    self.delete(file: n)
                }
                else if let f = getFolder(id: c) {
                    self.delete(file: f)
                }
            }
        }
        
        self.notes = loadNotes()
        self.folders = loadFolders()
    }
    
    public static func getFolder(id: String) -> Folder? {
        for f in folders {
            if f.id == id {
                return f
            }
        }
        return nil
    }
    
    public static func getNote(id: String) -> NoteX? {
        for n in notes {
            if n.id == id {
                return n
            }
        }
        return nil
    }
    
    public static func add(note: NoteX) -> Bool {
        if self.notes.contains(note) {
            return false
        }
        self.notes.append(note)
        self.save(file: note)
        return true
    }
    
    public static func add(folder: Folder) -> Bool {
        if self.folders.contains(folder) {
            return false
        }
        self.folders.append(folder)
        self.save(file: folder)
        return true
    }
    
    public static func importNoteFile(url: URL) -> NoteX? {
        do {
            let data = try Data(contentsOf: url)
            if let decodedNote = decodeNoteFromData(data: data) {
                return decodedNote
            }
        } catch {
            log.error("Failed to import note from file.")
        }
        return nil
    }
    
    public static func decodeNoteFromData(data: Data) -> NoteX? {
        if let decodedDataArray = try? NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(data) as? [Data] {
            if decodedDataArray.count >= 1 {
                let jsonDecoder = JSONDecoder()
                if let note = try? jsonDecoder.decode(NoteX.self, from: decodedDataArray[0]) {
                    return note
                }
            }
        }
        return nil
    }
    public static func decodeFolderFromData(data: Data) -> Folder? {
        if let decodedDataArray = try? NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(data) as? [Data] {
            if decodedDataArray.count >= 1 {
                let jsonDecoder = JSONDecoder()
                if let folder = try? jsonDecoder.decode(Folder.self, from: decodedDataArray[0]) {
                    return folder
                }
            }
        }
        return nil
    }
    
    public static func wipe() {
        for note in self.notes {
            let noteURL = self.getNotesDirectory().appendingPathComponent(note.id + ".sketchnote")
            if FileManager.default.fileExists(atPath: noteURL.path) {
                try? FileManager.default.removeItem(atPath: noteURL.path)
            }
            log.info("Deleted note.")
        }
        self.notes = [NoteX]()
        for folder in self.folders {
            let folderURL = self.getFoldersDirectory().appendingPathComponent(folder.id)
            if FileManager.default.fileExists(atPath: folderURL.path) {
                try? FileManager.default.removeItem(atPath: folderURL.path)
            }
            log.info("Deleted folder.")
        }
        self.notes = [NoteX]()
        log.info("All notes cleared.")

        
        self.currentFolder = nil
        log.info("All files have been wiped.")
        
        let cache = ImageCache.default
        cache.clearDiskCache{ log.info("KingFisher image cache cleared.") }
    }
    
    // MARK: Folder traversal
    public static func setCurrentFolder(folder: Folder?) {
        currentFolder = folder
        currentFoldersHierarchy = [Folder]()
        if let folder = folder {
            currentFoldersHierarchy.append(folder)
            if folder.parent != nil {
                var parent = getFolder(id: folder.parent!)
                while parent != nil {
                    currentFoldersHierarchy.append(parent!)
                    if parent!.parent != nil {
                        parent = getFolder(id: parent!.parent!)
                    }
                    else {
                        parent = nil
                    }
                }
            }
        }
        currentFoldersHierarchy = currentFoldersHierarchy.reversed()
    }
    
    public static func move(file: File, toFolder folder: Folder) {
        if file.parent == folder.id {
            return
        }
        if let previousParentFolderID = file.parent {
            if let previousParentFolder = getFolder(id: previousParentFolderID) {
                previousParentFolder.removeChild(file: file)
                self.save(file: previousParentFolder)
            }
        }
        folder.addChild(file: file)
        self.save(file: file)
        self.save(file: folder)
    }
}

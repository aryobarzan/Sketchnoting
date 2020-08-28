//
//  NeoLibrary.swift
//  Sketchnoting
//
//  Created by Aryobarzan on 06/07/2020.
//  Copyright © 2020 Aryobarzan. All rights reserved.
//

import UIKit
import PDFKit
import Foundation

import ZIPFoundation

class NeoLibrary {
    public static var currentLocation: URL = getHomeDirectoryURL()
    private static let neoLibraryQueue = DispatchQueue(label: "NeoLibraryQueue", qos: .background)
    
    static var receivedNotesController = ReceivedNotesController()
    
    public static func getDocumentsURL() -> URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        let documentsDirectory = paths[0]
        return documentsDirectory
    }
    
    public static func getHomeDirectoryURL() -> URL {
        let documentsPath = self.getDocumentsURL()
        let homeURL = documentsPath.appendingPathComponent("Home")
        do
        {
            if !FileManager.default.fileExists(atPath: homeURL.path) {
                try FileManager.default.createDirectory(atPath: homeURL.path, withIntermediateDirectories: true, attributes: nil)
            }
            return homeURL
        }
        catch let error as NSError
        {
            log.error("Unable to create directory \(error.debugDescription)")
        }
        return homeURL
    }
    
    public static func isHomeDirectory(url: URL) -> Bool {
        var temp0 = url.absoluteString
        if temp0.starts(with: "file:///private") {
            temp0 = "file:///" + String(temp0[16..<temp0.count])
        }
        var temp1 = self.getHomeDirectoryURL().absoluteString
        if temp1.starts(with: "file:///private") {
            temp1 = "file:///" + String(temp1[16..<temp1.count])
        }
        return temp0 == temp1
    }
    
    public static func getFiles(atURL url: URL = NeoLibrary.currentLocation, foldersOnly: Bool = false) -> [(URL, File)] {
        var files = [(URL, File)]()
        do {
            let fileURLs = try FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil, options: .skipsHiddenFiles)
            for url in fileURLs {
                do {
                    if url.hasDirectoryPath {
                        let file = File(name: url.deletingPathExtension().lastPathComponent)
                        files.append((url, file))
                    }
                    else {
                        if !foldersOnly {
                            let data = try Data(contentsOf: url)
                            if let decoded = self.decodeNoteFromData(data: data) {
                                files.append((url, decoded))
                            }
                        }
                    }
                } catch {
                    log.error(error)
                }
            }
        } catch {
            log.error("Failed to load current files: \(error.localizedDescription)")
        }
        return files
    }
    
    public static func getNotes() -> [(URL, Note)] {
        var notes = [(URL, Note)]()
        if let enumerator = FileManager.default.enumerator(at: self.getHomeDirectoryURL(), includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles, .skipsPackageDescendants]) {
            for case let fileURL as URL in enumerator {
                do {
                    let fileAttributes = try fileURL.resourceValues(forKeys:[.isRegularFileKey])
                    if fileAttributes.isRegularFile! {
                        do {
                            let data = try Data(contentsOf: fileURL)
                            if let note = self.decodeNoteFromData(data: data) {
                                notes.append((fileURL, note))
                            }
                        } catch {}
                        
                    }
                } catch { log.error(error) }
            }
        }
        return notes
    }
    
    public static func save(note: Note, url: URL) {
        neoLibraryQueue.async {
            if let encoded = note.encodeFileAsData() {
                try? encoded.write(to: url)
                log.info("Note \(note.getName()) saved.")
            }
        }
    }
    
    private static func saveSynchronously(note: Note, url: URL) {
        if let encoded = note.encodeFileAsData() {
            try? encoded.write(to: url)
            log.info("Note \(note.getName()) saved synchronously.")
        }
    }
    
    public static func delete(url: URL) {
        do {
            if FileManager.default.fileExists(atPath: url.path) {
                try FileManager.default.removeItem(atPath: url.path)
                log.info("Deleted file \(url.lastPathComponent).")
            }
            else {
                log.error("File to delete \(url.lastPathComponent) could not be found on disk.")
            }
        } catch {
            log.error("Failed to delete file \(url.lastPathComponent).")
        }
    }

    public static func move(file: File, from source: URL, to destination: URL) -> URL? {
        // Missing: recursive destination handling necessary?
        if source != destination {
            do
            {
                var name = file.getName()
                var tmp = name
                if file is Note {
                    tmp = name + ".sketchnote"
                }
                while FileManager.default.fileExists(atPath: destination.appendingPathComponent(tmp).path) {
                    name = name + " 2"
                    if file is Note {
                        tmp = name + ".sketchnote"
                    }
                }
                file.setName(name: name)
                if file is Note {
                    name = name + ".sketchnote"
                }
                try FileManager.default.moveItem(at: source, to: destination.appendingPathComponent(name))
                log.info("Moved file \(file.getName()).")
                return destination.appendingPathComponent(name)
            }
            catch _ as NSError
            {
                log.error("Unable to move file \(file.getName()) to \(destination.path).")
            }
        }
        return nil
    }
    
    public static func rename(url: URL, file: File, name: String) -> URL? {
        if FileManager.default.fileExists(atPath: url.path) {
            var newName = name
            var tmp = newName
            if file is Note {
                tmp = name + ".sketchnote"
            }
            while FileManager.default.fileExists(atPath: url.deletingLastPathComponent().appendingPathComponent(tmp).path) {
                newName += " 2"
                if file is Note {
                    tmp = newName + ".sketchnote"
                }
            }
            file.setName(name: newName)
            if file is Note {
                newName += ".sketchnote"
            }
            let newURL = url.deletingLastPathComponent().appendingPathComponent(newName)
            do {
                try FileManager.default.moveItem(at: url, to: newURL)
                return newURL
            } catch {
                log.error("Error while trying to rename file.")
                log.error(error)
            }
        }
        return nil
    }
    
    public static func importNote(url: URL) {
        do {
            let data = try Data(contentsOf: url)
            if let note = self.decodeNoteFromData(data: data) {
                var n = note.getName()
                while FileManager.default.fileExists(atPath: self.currentLocation.appendingPathComponent(n + ".sketchnote").path) {
                    n = n + " 2"
                }
                let url = self.currentLocation.appendingPathComponent(n + ".sketchnote")
                let note = Note(name: n, documents: nil)
                self.saveSynchronously(note: note, url: url)
                log.info("Note imported.")
            }
        } catch {
            log.error("Failed to import note.")
        }
    }
    
    public static func add(note: Note) {
        var n = note.getName()
        while FileManager.default.fileExists(atPath: self.currentLocation.appendingPathComponent(n + ".sketchnote").path) {
            n = n + " 2"
        }
        let url = self.currentLocation.appendingPathComponent(n + ".sketchnote")
        note.setName(name: n)
        self.saveSynchronously(note: note, url: url)
        log.info("Note added.")
    }
    
    
    // Decoding
    public static func decodeNoteFromData(data: Data) -> Note? {
        if let decodedDataArray = try? NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(data) as? [Data] {
            if decodedDataArray.count >= 1 {
                let jsonDecoder = JSONDecoder()
                if let note = try? jsonDecoder.decode(Note.self, from: decodedDataArray[0]) {
                    return note
                }
            }
        }
        return nil
    }
    // File Creation
    
    public static func createFolder(name: String, root: URL = getHomeDirectoryURL()) -> (URL, File)? {
        do
        {
            var n = name
            while FileManager.default.fileExists(atPath: root.appendingPathComponent(n).path) {
                n = n + " 2"
            }
            let url = root.appendingPathComponent(n)
            try FileManager.default.createDirectory(atPath: url.path, withIntermediateDirectories: true, attributes: nil)
            return (url, File(name: name))
        }
        catch _ as NSError
        {
            log.error("Unable to create folder.")
        }
        return nil
    }
    
    public static func createNote(name: String, at location: URL = currentLocation) -> (URL, Note) {
        var n = name
        while FileManager.default.fileExists(atPath: location.appendingPathComponent(n + ".sketchnote").path) {
            n = n + " 2"
        }
        let url = location.appendingPathComponent(n + ".sketchnote")
        let note = Note(name: n, documents: nil)
        self.saveSynchronously(note: note, url: url)
        return (url, note)
    }
    
    public static func createNoteFromNotePages(notePages: [NotePage], at location: URL = currentLocation) -> (URL, Note) {
        let (url, note) = NeoLibrary.createNote(name: "Imported Note Pages")
        note.pages = notePages
        self.saveSynchronously(note: note, url: url)
        return (url, note)
    }
    
    public static func createNoteFromImages(images: [UIImage], at location: URL = currentLocation) -> (URL, Note) {
        var noteImages = [NoteImage]()
        for image in images {
            if let noteImage = NoteImage(image: image) {
                noteImages.append(noteImage)
            }
        }
        return createNoteFromNoteImages(noteImages: noteImages)
    }
    
    public static func createNoteFromNoteImages(noteImages: [NoteImage], at location: URL = currentLocation) -> (URL, Note) {
        let (url, note) = NeoLibrary.createNote(name: "Imported Images")
        for noteImage in noteImages {
            note.getCurrentPage().layers.append(noteImage)
        }
        self.saveSynchronously(note: note, url: url)
        return (url, note)
    }
    
    public static func createNoteFromTypedTexts(texts: [NoteTypedText], at location: URL = currentLocation) -> (URL, Note) {
        let (url, note) = NeoLibrary.createNote(name: "Imported Text Files")
        for t in texts {
            note.getCurrentPage().layers.append(t)
        }
        self.saveSynchronously(note: note, url: url)
        return (url, note)
    }
    
    public static func createNoteFromPDF(pdf: PDFDocument, at location: URL = currentLocation) -> (URL, Note) {
        var pdfTitle = "Imported PDF"
        if let attributes = pdf.documentAttributes {
            if let title = attributes["Title"] as? String {
                if !title.isEmpty {
                    pdfTitle = title
                }
            }
        }
        let (url, note) = NeoLibrary.createNote(name: pdfTitle)
        var setPDFForCurrentPage = false
        for i in 0..<pdf.pageCount {
            if let pdfPage = pdf.page(at: i) {
                if !setPDFForCurrentPage {
                    setPDFForCurrentPage = true
                    note.getCurrentPage().backdropPDFData = pdfPage.dataRepresentation
                }
                else {
                    let newPage = NotePage()
                    newPage.backdropPDFData = pdfPage.dataRepresentation
                    note.pages.append(newPage)
                }
            }
        }
        self.saveSynchronously(note: note, url: url)
        return (url, note)
    }
    
    public static func createDuplicate(note: Note, url: URL) -> (URL, Note) {
        var n = note.getName() + " (Copy)"
        while FileManager.default.fileExists(atPath: url.deletingLastPathComponent().appendingPathComponent(n + ".sketchnote").path) {
            n = n + " 2"
        }
        let duplicateURL =  url.deletingLastPathComponent().appendingPathComponent(n + ".sketchnote")
        let documents = note.getDocuments()
        let duplicate = Note(name: n, documents: documents)
        duplicate.tags = note.tags
        duplicate.pages = note.pages
        self.saveSynchronously(note: duplicate, url: duplicateURL)
        return (duplicateURL, duplicate)
    }
    
    public static func createBackup(progressView: UIProgressView? = nil) -> URL? {
        let fileManager = FileManager()
        let sourceURL = URL(fileURLWithPath: getHomeDirectoryURL().path)
        let date = Date()
        let calendar = Calendar.current
        let year = calendar.component(.year, from: date)
        let month = calendar.component(.month, from: date)
        let day = calendar.component(.day, from: date)
        let hour = calendar.component(.hour, from: date)
        let minutes = calendar.component(.minute, from: date)
        let destinationURL = URL(fileURLWithPath: getDocumentsURL().path).appendingPathComponent("Backup-\(year)\(month)\(day)\(hour)\(minutes).zip")
        do {
            let progress = Progress()
            var _: NSKeyValueObservation = progress.observe(\.fractionCompleted) { [] object, change in
                log.info("Backup ZIP creation progress: \(object.fractionCompleted)")
                if let progressView = progressView {
                    progressView.progress = Float(object.fractionCompleted)
                }
            }
            try fileManager.zipItem(at: sourceURL, to: destinationURL, shouldKeepParent: false, compressionMethod: .deflate, progress: progress)
        } catch {
            log.error("Failed to create backup of library: \(error)")
            return nil
        }
        return destinationURL
    }
    
    enum ImportZIPResult {
        case Success
        case InvalidFile
        case InvalidZIP
        case Failure
    }
    public static func importZIP(url: URL) -> ImportZIPResult {
        let fileManager = FileManager()
        let sourceURL = url
        var destinationURL = currentLocation
        destinationURL.appendPathComponent(url.deletingPathExtension().lastPathComponent)
        
        // First verify if the content of the zip consists solely of directories and .sketchnote files
        guard let archive = Archive(url: sourceURL, accessMode: .read) else  {
            return .InvalidZIP
        }
        var valid = true
        archive.forEach { entry in
            if (!entry.path.hasSuffix("/")) {
                if (entry.path.lowercased().hasSuffix(".sketchnote")) {
                    log.info("Inspecting file \(entry.path)")
                    _ = try? archive.extract(entry) { data in
                        if self.decodeNoteFromData(data: data) != nil {
                            // Valid .sketchnote file
                        }
                        else {
                            log.error("Invalid file being imported! ZIP file import cancelled.")
                            valid = false
                        }
                    }
                }
                else {
                    valid = false
                }
            }
        }
        if (!valid) {
            return ImportZIPResult.InvalidFile
        }
        
        // ZIP file being imported is valid, so it is now saved to the app's library:
        do {
            try fileManager.createDirectory(at: destinationURL, withIntermediateDirectories: true, attributes: nil)
            try fileManager.unzipItem(at: sourceURL, to: destinationURL)
        } catch {
            log.error("Failed to extract ZIP file for import: \(error)")
            return ImportZIPResult.Failure
        }
        
        return ImportZIPResult.Success
    }
    
    // Helper
    public static func getCreationDate(url: URL) -> Date {
        if let attributes = try? FileManager.default.attributesOfItem(atPath: url.path) as [FileAttributeKey: Any] {
            if let date = attributes[FileAttributeKey.creationDate] as? Date {
                return date
            }
        }
        return Date()
    }
    public static func getModificationDate(url: URL) -> Date {
        if let attributes = try? FileManager.default.attributesOfItem(atPath: url.path) as [FileAttributeKey: Any] {
            if let date = attributes[FileAttributeKey.modificationDate] as? Date {
                return date
            }
        }
        return Date()
    }
}

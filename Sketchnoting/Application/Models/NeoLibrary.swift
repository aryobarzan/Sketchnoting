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
            logger.error("Home folder could not be created: \(error.debugDescription)")
        }
        return homeURL
    }
    
    public static func getTemporaryExportURL() -> URL {
        let documentsPath = self.getDocumentsURL()
        let exportTemporaryURL = documentsPath.appendingPathComponent("ExportTemporary")
        do
        {
            if !FileManager.default.fileExists(atPath: exportTemporaryURL.path) {
                try FileManager.default.createDirectory(atPath: exportTemporaryURL.path, withIntermediateDirectories: true, attributes: nil)
            }
            return exportTemporaryURL
        }
        catch let error as NSError
        {
            logger.error("ExportTemporary folder could not be created: \(error.debugDescription)")
        }
        return exportTemporaryURL
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
                            else {
                                logger.error("Detected invalid file - will attempt to delete...")
                                delete(url: url)
                            }
                        }
                    }
                } catch {
                    logger.error(error)
                }
            }
        } catch {
            logger.error("Failed to load current files: \(error.localizedDescription)")
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
                        } catch {
                            logger.error("Invalid file.")
                        }
                    }
                } catch { logger.error(error) }
            }
        }
        return notes
    }
    
    public static func getNoteIterator() -> NoteIterator {
        var urls = [URL]()
        if let enumerator = FileManager.default.enumerator(at: self.getHomeDirectoryURL(), includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles, .skipsPackageDescendants]) {
            for case let fileURL as URL in enumerator {
                do {
                    let fileAttributes = try fileURL.resourceValues(forKeys:[.isRegularFileKey])
                    if fileAttributes.isRegularFile! {
                        do {
                            let data = try Data(contentsOf: fileURL)
                            if self.decodeNoteFromData(data: data) != nil {
                                urls.append(fileURL)
                            }
                        } catch {
                            logger.error("Invalid file.")
                        }
                    }
                } catch { logger.error(error) }
            }
        }
        return NoteIterator(urls)
    }
    
    public static func getNote(from url: URL) -> Note? {
        do {
            let data = try Data(contentsOf: url)
            if let note = self.decodeNoteFromData(data: data) {
                return note
            }
        } catch {
            logger.error("Invalid note URL.")
            return nil
        }
        return nil
    }
    
    public static func save(note: Note, url: URL) {
        neoLibraryQueue.async {
            if let encoded = note.encodeFileAsData() {
                try? encoded.write(to: url)
                logger.info("Note \(note.getName()) saved.")
            }
        }
    }
    
    static func saveSynchronously(note: Note, url: URL) {
        if let encoded = note.encodeFileAsData() {
            try? encoded.write(to: url)
            logger.info("Note \(note.getName()) saved synchronously.")
        }
    }
    
    public static func delete(url: URL) {
        do {
            if FileManager.default.fileExists(atPath: url.path) {
                try FileManager.default.removeItem(atPath: url.path)
                logger.info("Deleted file \(url.lastPathComponent).")
            }
            else {
                logger.error("File to delete \(url.lastPathComponent) could not be found on disk.")
            }
        } catch {
            logger.error("Failed to delete file \(url.lastPathComponent).")
        }
    }
    
    private enum FileModificationType {
        case Move
        case Rename
    }
    
    private static func constructUniqueName(rename: String? = nil, file: File, url: URL, modificationType: FileModificationType = .Rename) -> (String, URL)? {
        var name = file.getName()
        if rename != nil {
            name = rename!
        }
        var tmp = (modificationType == .Move ? url : url.deletingLastPathComponent()).appendingPathComponent((file is Note) ? name + ".sketchnote" : name)
        while FileManager.default.fileExists(atPath: tmp.path) {
            name += " (2)"
            tmp = (modificationType == .Move ? url : url.deletingLastPathComponent()).appendingPathComponent((file is Note) ? name + ".sketchnote" : name)
        }
        file.setName(name: name)
        return (name, tmp)
    }

    public static func move(file: File, from source: URL, to destination: URL) -> URL? {
        if source != destination {
            do
            {
                if let (_, uniqueURL) = self.constructUniqueName(file: file, url: destination, modificationType: .Move) {
                    try FileManager.default.moveItem(at: source, to: uniqueURL)
                    logger.info("Moved file \(file.getName()) to \(uniqueURL.absoluteString).")
                    return uniqueURL
                }
            }
            catch _ as NSError
            {
                logger.error("Unable to move file \(file.getName()) to \(destination.path).")
            }
        }
        return nil
    }
    
    public static func rename(url: URL, file: File, name: String) -> URL? {
        if FileManager.default.fileExists(atPath: url.path) {
            if let (_, uniqueURL) = self.constructUniqueName(rename: name, file: file, url: url, modificationType: .Rename) {
                do {
                    try FileManager.default.moveItem(at: url, to: uniqueURL)
                    logger.info("File renamed.")
                    return uniqueURL
                } catch {
                    logger.error("Error while trying to rename file.")
                    logger.error(error)
                }
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
                    n = n + " (2)"
                }
                let url = self.currentLocation.appendingPathComponent(n + ".sketchnote")
                let note = Note(name: n, documents: nil)
                self.saveSynchronously(note: note, url: url)
                logger.info("Note imported.")
            }
        } catch {
            logger.error("Failed to import note.")
        }
    }
    
    public static func add(note: Note) {
        var n = note.getName()
        while FileManager.default.fileExists(atPath: self.currentLocation.appendingPathComponent(n + ".sketchnote").path) {
            n = n + " (2)"
        }
        let url = self.currentLocation.appendingPathComponent(n + ".sketchnote")
        note.setName(name: n)
        self.saveSynchronously(note: note, url: url)
        logger.info("Note added.")
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
    public static func createFolder(name: String, root: URL = currentLocation) -> (URL, File)? {
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
            logger.error("Unable to create folder.")
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
        return (url, note)
    }
    
    public static func createNoteFrom(notePages: [NotePage], at location: URL = currentLocation) -> (URL, Note) {
        let (url, note) = NeoLibrary.createNote(name: "Imported Note Pages")
        note.pages = notePages
        return (url, note)
    }
    
    public static func createNoteFrom(images: [UIImage], at location: URL = currentLocation) -> (URL, Note) {
        var noteImages = [NoteImage]()
        for image in images {
            let noteImage = NoteImage(image: image)
            noteImages.append(noteImage)
        }
        return createNoteFrom(noteImages: noteImages)
    }
    
    public static func createNoteFrom(noteImages: [NoteImage], at location: URL = currentLocation) -> (URL, Note) {
        let (url, note) = NeoLibrary.createNote(name: "Imported Images")
        for noteImage in noteImages {
            note.getCurrentPage().add(layer: noteImage)
        }
        return (url, note)
    }
    
    public static func createNoteFrom(typedTexts: [NoteTypedText], at location: URL = currentLocation) -> (URL, Note) {
        let (url, note) = NeoLibrary.createNote(name: "Imported Text Files")
        for typedText in typedTexts {
            note.getCurrentPage().add(layer: typedText)
        }
        return (url, note)
    }
    
    public static func createNoteFrom(pdf: PDFDocument, at location: URL = currentLocation) -> (URL, Note) {
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
                    note.getCurrentPage().set(pdfDocument: pdfPage.dataRepresentation)
                }
                else {
                    let newPage = NotePage()
                    newPage.set(pdfDocument: pdfPage.dataRepresentation)
                    note.pages.append(newPage)
                }
            }
        }
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
    
    public static func createBackup(completion: @escaping (URL?) -> ()) {
        DispatchQueue.global().async {
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
                    logger.info("Backup ZIP creation progress: \(object.fractionCompleted)")
                }
                try fileManager.zipItem(at: sourceURL, to: destinationURL, shouldKeepParent: false, compressionMethod: .deflate, progress: progress)
            } catch {
                logger.error("Failed to create backup of library: \(error)")
                completion(nil)
            }
            completion(destinationURL)
        }
    }
    
    public static func clearTemporaryExportFolder() {
        let fileManager = FileManager()
        let tempExportFile = getDocumentsURL().appendingPathComponent("Sketchnoting-Export.zip")
        if fileManager.fileExists(atPath: tempExportFile.path) {
            try? fileManager.removeItem(at: tempExportFile)
        }
        do {
            let enumerator = FileManager.default.enumerator(at: getTemporaryExportURL(),
                                    includingPropertiesForKeys: nil,
                                                       options: [.skipsHiddenFiles], errorHandler: { (url, error) -> Bool in
                                                        logger.error(error)
                                                                return true
            })!
            for case let fileURL as URL in enumerator {
                try fileManager.removeItem(at: fileURL)
            }
        } catch {
            logger.error("Could not clear temporary export folder: \(error)")
        }
    }
    
    public static func createFileForExportOf(note: Note, exportType: ExportAsType = .Sketchnote) -> URL? {
        var destinationURL = URL(fileURLWithPath: getTemporaryExportURL().path).appendingPathComponent(note.getName())
        let queue = OperationQueue()
        do {
            switch exportType {
            case .Sketchnote:
                destinationURL = destinationURL.appendingPathExtension("sketchnote")
                if let data = note.encodeFileAsData() {
                    try data.write(to: destinationURL)
                }
                break
            case .PDF:
                destinationURL = destinationURL.appendingPathExtension("pdf")
                queue.addOperation {
                    note.createPDF() { pdf in
                        do {
                            if let pdf = pdf {
                                try pdf.write(to: destinationURL)
                            }
                        } catch {
                            logger.error("PDF generation for note failed: \(error)")
                        }
                    }
                }
                break
            case .Image:
                destinationURL = destinationURL.appendingPathExtension(".jpg")
                if note.pages.count == 1 {
                    queue.addOperation {
                        note.getPreviewImage() { image in
                            do {
                                if let jpg = image.jpegData(compressionQuality: 1.0) {
                                    try jpg.write(to: destinationURL)
                                }
                            } catch {
                                logger.error("Image generation for note failed: \(error)")
                            }
                        }
                    }
                }
                else if note.pages.count > 1 {
                    let exportNoteAsImagesFolderURL = getTemporaryExportURL().appendingPathComponent(note.getName() + " (Images)")
                    do
                    {
                        if !FileManager.default.fileExists(atPath: exportNoteAsImagesFolderURL.path) {
                            try FileManager.default.createDirectory(atPath: exportNoteAsImagesFolderURL.path, withIntermediateDirectories: true, attributes: nil)
                        }
                    }
                    catch let error as NSError
                    {
                        logger.error("Unable to create directory \(error.debugDescription)")
                    }
                    for i in 0..<note.pages.count {
                        
                        let pageURL = exportNoteAsImagesFolderURL.appendingPathComponent( "Page_\(i+1).jpg")
                        queue.addOperation {
                            let page = note.pages[i]
                            page.getAsImage() { image in
                                do {
                                    if let jpg = image.jpegData(compressionQuality: 1.0) {
                                        try jpg.write(to: pageURL)
                                    }
                                } catch {
                                    logger.error("Image generation for note failed: \(error)")
                                }
                            }
                        }
                    }
                    destinationURL = exportNoteAsImagesFolderURL
                }
                break
            }
        }
        catch {
            logger.error("Creating file for export of note \(note.getName()) failed: \(error)")
            return nil
        }
        queue.waitUntilAllOperationsAreFinished()
        if FileManager.default.fileExists(atPath: destinationURL.path) {
            return destinationURL
        }
        else {
            return nil
        }
    }
    
    public static func createZIPForExportOf(folder: URL, exportType: ExportAsType = .Sketchnote) -> URL {
        let fileManager = FileManager.default
        let sourceURL = URL(fileURLWithPath: folder.path)
        let destinationURL = URL(fileURLWithPath: getTemporaryExportURL().path).appendingPathComponent(folder.lastPathComponent + ".zip")
        do {
            switch exportType {
            case .Sketchnote:
                try fileManager.zipItem(at: sourceURL, to: destinationURL, shouldKeepParent: false, compressionMethod: .deflate)
                break
            case .PDF, .Image:
                let tempDestinationURL = getTemporaryExportURL().appendingPathComponent(folder.lastPathComponent)
                try fileManager.copyItem(at: sourceURL, to: tempDestinationURL)
                let resourceKeys : [URLResourceKey] = [.isDirectoryKey]
                let enumerator = FileManager.default.enumerator(at: tempDestinationURL,
                                        includingPropertiesForKeys: resourceKeys,
                                                           options: [.skipsHiddenFiles], errorHandler: { (url, error) -> Bool in
                                                            logger.error(error)
                                                                    return true
                })!
                let queue = OperationQueue()
                for case let fileURL as URL in enumerator {
                    let resourceValues = try fileURL.resourceValues(forKeys: Set(resourceKeys))
                    if !resourceValues.isDirectory! {
                        if let data = try? Data(contentsOf: fileURL) {
                            if let note = decodeNoteFromData(data: data) {
                                queue.addOperation {
                                    switch exportType {
                                    case .PDF:
                                        note.createPDF() { pdf in
                                            if let pdf = pdf {
                                                do {
                                                    try pdf.write(to: fileURL.deletingPathExtension().appendingPathExtension("pdf"))
                                                    try fileManager.removeItem(at: fileURL)
                                                }
                                                catch {
                                                    logger.error(error)
                                                }
                                            }
                                        }
                                        break
                                    default:
                                        logger.error("Non-implemented export type for folder.")
                                        break
                                    }
                                }
                            }
                        }
                    }
                }
                queue.addBarrierBlock {
                    do {
                        try fileManager.zipItem(at: tempDestinationURL, to: destinationURL, shouldKeepParent: false, compressionMethod: .deflate)
                        try fileManager.removeItem(at: tempDestinationURL)
                    } catch {
                        logger.error(error)
                    }
                }
                break
            }
        } catch {
            logger.error("Failed to create zip of folder: \(error)")
        }
        return destinationURL
    }
    
    public static func createZIPOfExportFolder() -> URL? {
        let destinationURL = getDocumentsURL().appendingPathComponent("Sketchnoting-Export.zip")
        logger.info(destinationURL.absoluteString)
        do {
            logger.info(1)
            try FileManager.default.zipItem(at: getTemporaryExportURL(), to: destinationURL, shouldKeepParent: false, compressionMethod: .none)
            logger.info(2)
        }
        catch {
            logger.error("Created a ZIP of the export folder failed.")
            logger.error(error)
            return nil
        }
        if FileManager.default.fileExists(atPath: destinationURL.path) {
            return destinationURL
        }
        else {
            return nil
        }
    }
    // ----
    
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
                    logger.info("Inspecting file \(entry.path)")
                    _ = try? archive.extract(entry) { data in
                        if self.decodeNoteFromData(data: data) != nil {
                            // Valid .sketchnote file
                        }
                        else {
                            logger.error("Invalid file being imported! ZIP file import cancelled.")
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
            logger.error("Failed to extract ZIP file for import: \(error)")
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
    
    public static func getFileSize(url: URL) -> Double {
        if let attributes = try? FileManager.default.attributesOfItem(atPath: url.path) as [FileAttributeKey: Any] {
            if let size = attributes[FileAttributeKey.size] as? UInt64 {
                return Double(size) / 1000000.0 // bytes to megabytes
            }
        }
        return -1.0
    }
    
    public static func getFolderItemsCount(url: URL) -> Int {
        let dirContents = try? FileManager.default.contentsOfDirectory(atPath: url.path)
        let count = dirContents?.count
        if count != nil {
            return Int(count!)
        }
        else {
            return -1
        }
    }
    
    // MARK: Document storage
    private static var documentsIndex: [String : [String]] = [String : [String]]()
    private static func getDocumentsURL(for type: DocumentType) -> URL {
        let documentsPath = self.getDocumentsURL()
        let documentsURL = documentsPath.appendingPathComponent("Documents")
        let documentTypeFolderURL = documentsURL.appendingPathComponent(type.rawValue)
        do
        {
            if !FileManager.default.fileExists(atPath: documentsURL.path) {
                try FileManager.default.createDirectory(atPath: documentsURL.path, withIntermediateDirectories: true, attributes: nil)
            }
            if !FileManager.default.fileExists(atPath: documentTypeFolderURL.path) {
                try FileManager.default.createDirectory(atPath: documentTypeFolderURL.path, withIntermediateDirectories: true, attributes: nil)
            }
        }
        catch let error as NSError
        {
            logger.error("Documents folder could not be created: \(error.debugDescription)")
        }
        return documentTypeFolderURL
    }
    public static func store(document: Document, for note: Note?) {
        let documentURL = getDocumentsURL(for: document.documentType).appendingPathComponent(document.title)
        neoLibraryQueue.async {
            let encoder = JSONEncoder()
            if let encoded = try? encoder.encode(document) {
                do
                {
                    try encoded.write(to: documentURL)
                    logger.info("[\(document.documentType.rawValue)] Document \(document.title) stored.")
                    if let note = note {
                        if documentsIndex[note.getID()] == nil {
                            documentsIndex[note.getID()] = [String]()
                        }
                        documentsIndex[note.getID()]!.append(documentURL.path)
                    }
                }
                catch let error as NSError
                {
                    logger.error("[\(document.documentType.rawValue)] Document \(document.title) could not be stored: \(error)")
                }
            }
        }
    }
    private static func loadDocument(url: URL) -> Document? {
        if FileManager.default.fileExists(atPath: url.path) {
            do {
                let decoder = JSONDecoder()
                let data = try Data(contentsOf: url)
                if let type = DocumentType(rawValue: url.deletingLastPathComponent().lastPathComponent) {
                    switch type {
                    case .TAGME:
                        return try decoder.decode(TAGMEDocument.self, from: data)
                    case .WAT:
                        return try decoder.decode(WATDocument.self, from: data)
                    case .BioPortal:
                        return try decoder.decode(BioPortalDocument.self, from: data)
                    case .Chemistry:
                        return try decoder.decode(CHEBIDocument.self, from: data)
                    case .ALMAAR:
                        return try decoder.decode(ARDocument.self, from: data)
                    case .Other:
                        return try decoder.decode(Document.self, from: data)
                    }
                }
            } catch {
                logger.error("Document failed to load from disk: \(url.path)")
            }
        }
        return nil
    }
    public static func getDocuments(for note: Note?) -> [Document] {
        var documents = [Document]()
        if let note = note {
            if let documentPaths = documentsIndex[note.getID()] {
                for documentPath in documentPaths {
                    if let document = loadDocument(url: URL(fileURLWithPath: documentPath)) {
                        documents.append(document)
                    }
                }
            }
        }
        // Missing - load all documents
        return documents
    }
}

struct NoteIterator {
    let noteURLs: [URL]
    var index = 0
    
    init(_ noteURLs: [URL]) {
        self.noteURLs = noteURLs
    }
    
    mutating func next() -> (URL, Note)? {
        if index < noteURLs.count {
            var url = noteURLs[index]
            var note = NeoLibrary.getNote(from: noteURLs[index])
            self.index += 1
            while note == nil && index < noteURLs.count {
                url = noteURLs[index]
                note = NeoLibrary.getNote(from: noteURLs[index])
                self.index += 1
            }
            if note == nil {
                return nil
            }
            else {
                return (url, note!)
            }
        }
        else {
            return nil
        }
    }
    
    mutating func reset() {
        self.index = 0
    }
}

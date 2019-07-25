//
//  Sketchnote.swift
//  Sketchnoting
//
//  Created by Aryobarzan on 26/02/2019.
//  Copyright © 2019 Aryobarzan. All rights reserved.
//

import UIKit

class Sketchnote: Note, Equatable {
    
    var id: String!
    var creationDate: Date!
    var updateDate: Date?
    var image: UIImage?
    var documents: [Document]?
    var drawings: [String]? // recognized drawings' labels
    var drawingViewRects: [CGRect]?
    var paths: NSMutableArray?
    var textDataArray: [TextData]!
    
    enum CodingKeys: String, CodingKey {
        case id
        case creationDate
        case updateDate
        case image
        case relatedDocuments = "relatedDocuments"
        case drawings = "drawings"
        case drawingViewRects = "drawingViewRects"
    }
    
    //MARK: Initialization
    
    init?(image: UIImage?, relatedDocuments: [Document]?, drawings: [String]?) {
        self.id = UUID().uuidString
        self.creationDate = Date.init(timeIntervalSinceNow: 0)
        self.documents = relatedDocuments ?? [Document]()
        self.drawings = drawings ?? [String]()
        self.image = image
        self.textDataArray = [TextData]()
    }
    
    //MARK: Persistence
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(creationDate.timeIntervalSince1970, forKey: .creationDate)
        try container.encode(updateDate?.timeIntervalSince1970, forKey: .updateDate)
        try container.encode(documents, forKey: .relatedDocuments)
        try container.encode(drawings, forKey: .drawings)
        try container.encode(drawingViewRects, forKey: .drawingViewRects)
        if image != nil {
            let imageData: Data = image!.pngData()!
            let strBase64 = imageData.base64EncodedString(options: .lineLength64Characters)
            try container.encode(strBase64, forKey: .image)
        }
    }
    
    required init(from decoder: Decoder) throws {
        print("Decoding sketchnote")
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try? container.decode(String.self, forKey: .id)
        creationDate = Date(timeIntervalSince1970: try container.decode(TimeInterval.self, forKey: .creationDate))
        do {
            _ = try container.decode(TimeInterval.self, forKey: .updateDate)
            updateDate = Date(timeIntervalSince1970: try container.decode(TimeInterval.self, forKey: .updateDate))
        } catch {
        }
        documents = try? container.decode([Document].self, forKey: .relatedDocuments) 
        drawings = try? container.decode([String].self, forKey: .drawings)
        drawingViewRects = try? container.decode([CGRect].self, forKey: .drawingViewRects)
        do {
            let strBase64: String = try container.decode(String.self, forKey: .image)
            let dataDecoded: Data = Data(base64Encoded: strBase64, options: .ignoreUnknownCharacters)!
            image = UIImage(data: dataDecoded)
        } catch {
        }
        
        self.loadPaths()
        self.loadTextDataArray()
        print("Sketchnote decoded")
    }
    
    public func save() {
        let encoder = JSONEncoder()
        
        if let encoded = try? encoder.encode(self) {
            UserDefaults.sketchnotes.set(encoded, forKey: self.id)
            print("Note " + id + " saved.")
            
            if self.paths != nil {
                self.savePaths()
            }
            self.saveTextDataArray()
        }
        else {
            print("Encoding failed for note " + id + ".")
        }
    }
    private func savePaths() {
        let DocumentsDirectory = FileManager().urls(for: .documentDirectory, in: .userDomainMask).first!
        let ArchiveURLPathArray = DocumentsDirectory.appendingPathComponent("NotePaths-" + self.id)
        if let encoded = try? NSKeyedArchiver.archivedData(withRootObject: self.paths, requiringSecureCoding: false) {
            try! encoded.write(to: ArchiveURLPathArray)
            print("Note " + id + " paths saved.")
        }
        else {
            print("Failed to encode paths for note " + id + ".")
        }
    }
    private func loadPaths() {
        let DocumentsDirectory = FileManager().urls(for: .documentDirectory, in: .userDomainMask).first!
        let ArchiveURLPathArray = DocumentsDirectory.appendingPathComponent("NotePaths-" + self.id)
        guard let codedData = try? Data(contentsOf: ArchiveURLPathArray) else { return }
        guard let data = ((try? NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(codedData) as?
            NSMutableArray) as NSMutableArray??) else { return }
        print("Paths for note " + id + " loaded.")
        self.paths = data
    }
    private func saveTextDataArray() {
        let DocumentsDirectory = FileManager().urls(for: .documentDirectory, in: .userDomainMask).first!
        let ArchiveURLPathArray = DocumentsDirectory.appendingPathComponent("NoteTextDataArray-" + self.id)
        if let encoded = try? NSKeyedArchiver.archivedData(withRootObject: self.textDataArray, requiringSecureCoding: false) {
            try! encoded.write(to: ArchiveURLPathArray)
            print("Note " + id + " text data array saved.")
        }
        else {
            print("Failed to encode text data array for note " + id + ".")
        }
    }
    private func loadTextDataArray() {
        let DocumentsDirectory = FileManager().urls(for: .documentDirectory, in: .userDomainMask).first!
        let ArchiveURLPathArray = DocumentsDirectory.appendingPathComponent("NoteTextDataArray-" + self.id)
        guard let codedData = try? Data(contentsOf: ArchiveURLPathArray) else { return }
        guard let data = ((try? NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(codedData) as?
            [TextData]) as [TextData]??) else { return }
        print("Text data array for note " + id + " loaded.")
        self.textDataArray = data
    }
    
    public func delete() {
        clearPaths()
        clearTextData()
        UserDefaults.sketchnotes.removeObject(forKey: id)
    }
    
    public func clearPaths() {
        do {
            let DocumentsDirectory = FileManager().urls(for: .documentDirectory, in: .userDomainMask).first!
            let ArchiveURLPathArray = DocumentsDirectory.appendingPathComponent("NotePaths-" + id)
            try FileManager().removeItem(atPath: ArchiveURLPathArray.absoluteString)
        } catch {
        }
        self.paths = nil
    }
    
    public func clearTextData() {
        do {
            let DocumentsDirectory = FileManager().urls(for: .documentDirectory, in: .userDomainMask).first!
            let ArchiveURLPathArray = DocumentsDirectory.appendingPathComponent("NoteTextDataArray-" + id)
            try FileManager().removeItem(atPath: ArchiveURLPathArray.absoluteString)
        } catch {
        }
        self.textDataArray = [TextData]()
    }
    
    //MARK: updating data
    public func clear() {
        documents = [Document]()
        drawings = [String]()
        clearTextData()
        clearPaths()
    }
    
    func addDocument(document: Document) {
        var exists = false
        if documents == nil {
            documents = [Document]()
        }
        for d in documents! {
            if d.title == document.title {
                exists = true
                break
            }
        }
        if !exists {
            documents!.append(document)
        }
    }
    // This function only stores a recognized drawing's label for a note. The drawing itself (i.e. an image) is not stored.
    // Only the label is necessary, as it is used for search results.
    func addDrawing(drawing: String) {
        var exists = false
        if drawings == nil {
            drawings = [String]()
        }
        for d in drawings! {
            if d == drawing.lowercased() {
                exists = true
                break
            }
        }
        if !exists {
            drawings!.append(drawing.lowercased())
        }
    }
    
    func addDrawingViewRect(rect: CGRect) {
        var exists = false
        if drawingViewRects == nil {
            drawingViewRects = [CGRect]()
        }
        for r in drawingViewRects! {
            if r == rect {
                exists = true
                break
            }
        }
        if !exists {
            drawingViewRects!.append(rect)
        }
    }
    
    func setUpdateDate() {
        self.updateDate = Date.init(timeIntervalSinceNow: 0)
    }
    
    //MARK: recognized text
    public func getText() -> String {
        var text: String = ""
        for textData in textDataArray {
            text = text + " " + textData.spellchecked
        }
        return text
    }

    static func == (lhs: Sketchnote, rhs: Sketchnote) -> Bool {
        if lhs.id == rhs.id {
            return true
        }
        return false
    }
}

extension UserDefaults {
    static var sketchnotes: UserDefaults {
        return UserDefaults(suiteName: "lu.uni.coast.sketchnoting.sketchnotes")!
    }
    static var collections: UserDefaults {
        return UserDefaults(suiteName: "lu.uni.coast.sketchnoting.collections")!
    }
}

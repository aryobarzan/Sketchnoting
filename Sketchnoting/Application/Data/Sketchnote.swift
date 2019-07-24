//
//  Sketchnote.swift
//  Sketchnoting
//
//  Created by Aryobarzan on 26/02/2019.
//  Copyright © 2019 Aryobarzan. All rights reserved.
//

import UIKit
// This class contains every information related to a single sketchnote, except for the strokes drawn on the note's canvas.
// Where and how the strokes are stored&saved is explained in the ViewController.swift file
class Sketchnote: Note, Equatable {
    
    var id: String!
    var creationDate: Date!
    var updateDate: Date?
    var image: UIImage?
    var relatedDocuments: [Document]?
    var drawings: [String]?
    var recognizedText: String?
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
        case recognizedText
        case drawingViewRects = "drawingViewRects"
    }
    
    //MARK: Initialization
    
    init?(image: UIImage?, relatedDocuments: [Document]?, drawings: [String]?) {
        self.id = UUID().uuidString
        self.creationDate = Date.init(timeIntervalSinceNow: 0)
        self.relatedDocuments = relatedDocuments ?? [Document]()
        self.drawings = drawings ?? [String]()
        self.image = image
        self.textDataArray = [TextData]()
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(creationDate.timeIntervalSince1970, forKey: .creationDate)
        try container.encode(updateDate?.timeIntervalSince1970, forKey: .updateDate)
        try container.encode(relatedDocuments, forKey: .relatedDocuments)
        try container.encode(drawings, forKey: .drawings)
        try container.encode(recognizedText, forKey: .recognizedText)
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
        relatedDocuments = try? container.decode([Document].self, forKey: .relatedDocuments) 
        drawings = try? container.decode([String].self, forKey: .drawings)
        recognizedText = try? container.decode(String.self, forKey: .recognizedText)
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
    // A related document that has been found for this note is added to the note here.
    func addDocument(document: Document) {
        var exists = false
        if relatedDocuments == nil {
            relatedDocuments = [Document]()
        }
        for d in relatedDocuments! {
            if d.title == document.title {
                exists = true
                break
            }
        }
        if !exists {
            relatedDocuments!.append(document)
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
    // This function stores a drawing region's location and size for the note. This drawing region is manually inserted somewhere on the note's canvas by the user.
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
    // The == function is overriden to allow comparing two instances of a Sketchnote class with each other, to check if they are equal to each other
    // The unique identifier of a sketchnote is its creation date.
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

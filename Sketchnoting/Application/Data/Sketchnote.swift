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
    
    var creationDate: Date!
    var updateDate: Date?
    var image: UIImage?
    var relatedDocuments: [Document]?
    var drawings: [String]?
    var recognizedText: String?
    var drawingViewRects: [CGRect]?
    
    static let DocumentsDirectory = FileManager().urls(for: .documentDirectory, in: .userDomainMask).first!
    static let ArchiveURL = DocumentsDirectory.appendingPathComponent("sketchnotes")
    
    enum CodingKeys: String, CodingKey {
        case image
        case creationDate
        case updateDate
        case relatedDocuments = "relatedDocuments"
        case drawings = "drawings"
        case recognizedText
        case drawingViewRects = "drawingViewRects"
    }
    
    //MARK: Initialization
    
    init?(image: UIImage?, relatedDocuments: [Document]?, drawings: [String]?) {
        self.creationDate = Date.init(timeIntervalSinceNow: 0)
        self.relatedDocuments = relatedDocuments ?? [Document]()
        self.drawings = drawings ?? [String]()
        self.image = image
    }
    
    // This function is used to transform the instance of this class into a format that can be saved to the device's disk for persistence
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
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
    
    // This function is used to reload a saved note from the device's disk and to load each property contained in this class
    required init(from decoder: Decoder) throws {
        print("Decoding sketchnote")
        let container = try decoder.container(keyedBy: CodingKeys.self)

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
        print("Sketchnote decoded")
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
        if lhs.creationDate == rhs.creationDate {
            return true
        }
        return false
    }
}

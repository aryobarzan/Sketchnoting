//
//  Sketchnote.swift
//  Sketchnoting
//
//  Created by Aryobarzan on 26/02/2019.
//  Copyright © 2019 Aryobarzan. All rights reserved.
//

import UIKit

class Sketchnote: Note {
    
    var creationDate: Date!
    var updateDate: Date?
    var image: UIImage?
    var relatedDocuments: [Document]?
    var drawings: [String]?
    var recognizedText: String?
    
    static let DocumentsDirectory = FileManager().urls(for: .documentDirectory, in: .userDomainMask).first!
    static let ArchiveURL = DocumentsDirectory.appendingPathComponent("sketchnotes")
    
    enum CodingKeys: String, CodingKey {
        case image
        case creationDate
        case updateDate
        case relatedDocuments = "relatedDocuments"
        case drawings = "drawings"
        case recognizedText
    }
    
    //MARK: Initialization
    
    init?(image: UIImage?, relatedDocuments: [Document]?, drawings: [String]?) {
        self.creationDate = Date.init(timeIntervalSinceNow: 0)
        self.relatedDocuments = relatedDocuments ?? [Document]()
        self.drawings = drawings ?? [String]()
        self.image = image
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(creationDate.timeIntervalSince1970, forKey: .creationDate)
        try container.encode(updateDate?.timeIntervalSince1970, forKey: .updateDate)
        try container.encode(relatedDocuments, forKey: .relatedDocuments)
        try container.encode(drawings, forKey: .drawings)
        try container.encode(recognizedText, forKey: .recognizedText)
        
        if image != nil {
            let imageData: Data = image!.pngData()!
            let strBase64 = imageData.base64EncodedString(options: .lineLength64Characters)
            try container.encode(strBase64, forKey: .image)
        }
        
    }
    
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

        do {
            let strBase64: String = try container.decode(String.self, forKey: .image)
            let dataDecoded: Data = Data(base64Encoded: strBase64, options: .ignoreUnknownCharacters)!
            image = UIImage(data: dataDecoded)
        } catch {
        }
        print("Sketchnote decoded")
    }
    
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
    
    func setUpdateDate() {
        self.updateDate = Date.init(timeIntervalSinceNow: 0)
    }
    
}

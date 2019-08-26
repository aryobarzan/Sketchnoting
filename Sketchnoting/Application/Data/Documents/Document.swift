//
//  Document.swift
//  Sketchnoting
//
//  Created by Aryobarzan on 26/02/2019.
//  Copyright © 2019 Aryobarzan. All rights reserved.
//

import UIKit

protocol Visitable {
    func accept(visitor: DocumentVisitor)
}
protocol DocumentVisitor {
    func process(document: Document)
    func process(document: SpotlightDocument)
    func process(document: BioPortalDocument)
    func process(document: CHEBIDocument)
    func process(document: TAGMEDocument)
}

enum DocumentType: String, Codable {
    case Spotlight
    case TAGME
    case BioPortal
    case Chemistry
    case Other
}

class Document: Codable, Visitable, Equatable {
    static func == (lhs: Document, rhs: Document) -> Bool {
        if lhs.title == rhs.title {
            return true
        }
        return false
    }
    
    
    var title: String
    var description: String?
    var URL: String
    var documentType: DocumentType
    var previewImage: UIImage?
    var type: String
    
    private enum CodingKeys: String, CodingKey {
        case title = "Title"
        case description = "Description"
        case URL = "URL"
        case documentType = "DocumentType"
        case type = "Type"
        case previewImage = "PreviewImage"
    }
    
    init?(title: String, description: String?, URL: String, documentType: DocumentType, previewImage: UIImage?, type: String?){
        guard !title.isEmpty && !URL.isEmpty else {
            return nil
        }
        self.title = title
        self.description = description
        self.URL = URL
        self.documentType = documentType
        self.previewImage = previewImage
        self.type = type ?? "SpotlightDocument"
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(title, forKey: .title)
        try container.encode(description, forKey: .description)
        try container.encode(URL, forKey: .URL)
        try container.encode(documentType, forKey: .documentType)
        try container.encode(type, forKey: .type)
        print("Encoding image")
        if let previewImage = previewImage {
            if let pngData = previewImage.pngData() {
                let strBase64 = pngData.base64EncodedString(options: .lineLength64Characters)
                try container.encode(strBase64, forKey: .previewImage)
            }
            else  {
                if let jpgData = previewImage.jpegData(compressionQuality: 1) {
                    let strBase64 = jpgData.base64EncodedString(options: .lineLength64Characters)
                    try container.encode(strBase64, forKey: .previewImage)
                }
            }
        }
    }
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        do {
            title = try container.decode(String.self, forKey: CodingKeys.title)
        } catch {
            print(error)
            title = ""
        }
        do {
            description = try container.decode(String.self, forKey: .description)
        } catch {
            print(error)
            print("Note description decoding failed.")
            description = ""
        }
        
        URL = try container.decode(String.self, forKey: .URL)
        documentType = DocumentType(rawValue: try container.decode(String.self, forKey: .documentType)) ?? .Other
        type = try container.decode(String.self, forKey: .type)
        do {
            let strBase64: String = try container.decode(String.self, forKey: .previewImage)
            let dataDecoded: Data = Data(base64Encoded: strBase64, options: .ignoreUnknownCharacters)!
            previewImage = UIImage(data: dataDecoded)
            print("Document preview image decoded.")
        } catch {
            print("Document preview image decoding failed.")
        }
    }
    
    //MARK: Visitable
    func accept(visitor: DocumentVisitor) {
        visitor.process(document: self)
    }
}

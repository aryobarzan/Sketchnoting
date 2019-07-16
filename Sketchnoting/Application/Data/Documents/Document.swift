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
}
// This enum is used to let the user know the type of a found document.
// Currently only the case Spotlight is used, as that is the only source for retrieving related documents.
enum DocumentType: String, Codable {
    case Spotlight
    case BioOntology
    case Chemistry
    case Other
}

// This class contains the information for a document that is related to a note's text.
// All of its properties are required, except for 'description', which is the abstract text of the found document.
// As this abstract text is manually fetched from the document's page source code via a regular expression, it may at times fail, hence why it is an optional property.
class Document: Codable, Visitable {
    
    var title: String
    var description: String?
    var entityType: String?
    var URL: String
    var documentType: DocumentType
    //var rankPercentage: Double
    var previewImage: UIImage?
    //var mapImage: UIImage?
    
    private enum CodingKeys: String, CodingKey {
        case title
        case description
        case entityType
        case URL
        case documentType
        //case rankPercentage
        case previewImage
        //case mapImage
    }
    
    init?(title: String, description: String?, entityType: String?, URL: String, type: DocumentType){
        guard !title.isEmpty && !URL.isEmpty else {
            return nil
        }
        self.title = title
        self.description = description
        self.URL = URL
        self.documentType = type
        self.entityType = entityType
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(title, forKey: .title)
        try container.encode(description, forKey: .description)
        try container.encode(entityType, forKey: .entityType)
        try container.encode(URL, forKey: .URL)
        try container.encode(documentType, forKey: .documentType)
        if previewImage != nil {
            let imageData: Data = previewImage!.pngData()!
            let strBase64 = imageData.base64EncodedString(options: .lineLength64Characters)
            try container.encode(strBase64, forKey: .previewImage)
        }
    }
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        title = try container.decode(String.self, forKey: .title)
        description = try container.decode(String.self, forKey: .description)
        description = try container.decode(String.self, forKey: .entityType)
        URL = try container.decode(String.self, forKey: .URL)
        documentType = DocumentType(rawValue: try container.decode(String.self, forKey: .documentType)) ?? .Other
        
        do {
            let strBase64: String = try container.decode(String.self, forKey: .previewImage)
            let dataDecoded: Data = Data(base64Encoded: strBase64, options: .ignoreUnknownCharacters)!
            previewImage = UIImage(data: dataDecoded)
        } catch {
        }
    }
    
    //MARK: Visitable
    func accept(visitor: DocumentVisitor) {
        visitor.process(document: self)
    }
}

//
//  CHEBIDocument.swift
//  Sketchnoting
//
//  Created by Aryobarzan on 16/07/2019.
//  Copyright © 2019 Aryobarzan. All rights reserved.
//

import UIKit

class CHEBIDocument: BioPortalDocument {
    
    var moleculeImage: UIImage?
    
    private enum CodingKeys: String, CodingKey {
        case moleculeImage
    }
    
    override init?(title: String, description: String?, entityType: String?, URL: String, type: DocumentType, prefLabel: String, definition: String) {
        super.init(title: title, description: description, entityType: entityType, URL: URL, type: type, prefLabel: prefLabel, definition: definition)
    }
    
    override func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        if let moleculeImage = moleculeImage {
            let imageData: Data = moleculeImage.pngData()!
            let strBase64 = imageData.base64EncodedString(options: .lineLength64Characters)
            try container.encode(strBase64, forKey: .moleculeImage)
        }
        
        let superencoder = container.superEncoder()
        try super.encode(to: superencoder)
    }
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let superdecoder = try container.superDecoder()
        try super.init(from: superdecoder)
        
        do {
            let strBase64: String = try container.decode(String.self, forKey: .moleculeImage)
            let dataDecoded: Data = Data(base64Encoded: strBase64, options: .ignoreUnknownCharacters)!
            moleculeImage = UIImage(data: dataDecoded)
        } catch {
        }
    }
    
    //MARK: Visitable
    override func accept(visitor: DocumentVisitor) {
        visitor.process(document: self)
    }
}

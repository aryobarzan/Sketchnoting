//
//  TAGMEDocument.swift
//  Sketchnoting
//
//  Created by Aryobarzan on 26/08/2019.
//  Copyright © 2019 Aryobarzan. All rights reserved.
//

import UIKit

class TAGMEDocument: Document {
    
    var spot: String?
    var categories: [String]?
    var wikiPageID: Double?
    var mapImage: UIImage?
    
    private enum CodingKeys: String, CodingKey {
        case spot
        case categories = "categories"
        case wikiPageID
        case mapImage
    }
    
    init?(title: String, description: String?, URL: String, type: DocumentType, previewImage: UIImage?, spot: String?, categories: [String]?, wikiPageID: Double?) {
        self.spot = spot
        self.categories = categories
        self.wikiPageID = wikiPageID
        super.init(title: title, description: description, URL: URL, documentType: type, previewImage: previewImage)
    }
    
    override func encode(to encoder: Encoder) throws {
        try super.encode(to: encoder)
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(spot, forKey: .spot)
        try container.encode(categories, forKey: .categories)
        try container.encode(wikiPageID, forKey: .wikiPageID)
        if mapImage != nil {
            let imageData: Data = mapImage!.pngData()!
            let strBase64 = imageData.base64EncodedString(options: .lineLength64Characters)
            try container.encode(strBase64, forKey: .mapImage)
        }
        if let mapImage = mapImage {
            if let jpgData = mapImage.jpegData(compressionQuality: 1) {
                let strBase64 = jpgData.base64EncodedString(options: .lineLength64Characters)
                try container.encode(strBase64, forKey: .mapImage)
            }
            else if let pngData = mapImage.pngData() {
                let strBase64 = pngData.base64EncodedString(options: .lineLength64Characters)
                try container.encode(strBase64, forKey: .mapImage)
            }
        }
    }
    
    required init(from decoder: Decoder) throws {
        try super.init(from: decoder)
        
        let container = try decoder.container(keyedBy: CodingKeys.self)
        spot = try? container.decode(String.self, forKey: .spot)
        categories = try? container.decode([String].self, forKey: .categories)
        wikiPageID = try? container.decode(Double.self, forKey: .wikiPageID)
        do {
            let strBase64: String = try container.decode(String.self, forKey: .mapImage)
            let dataDecoded: Data = Data(base64Encoded: strBase64, options: .ignoreUnknownCharacters)!
            mapImage = UIImage(data: dataDecoded)
        } catch {
            print("No map image for this document.")
        }
    }
    
    //MARK: Visitable
    override func accept(visitor: DocumentVisitor) {
        visitor.process(document: self)
    }
}

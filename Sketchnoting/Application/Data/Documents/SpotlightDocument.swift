//
//  SpotlightDocument.swift
//  Sketchnoting
//
//  Created by Aryobarzan on 16/07/2019.
//  Copyright © 2019 Aryobarzan. All rights reserved.
//

import UIKit

class SpotlightDocument: Document {
    
    var rankPercentage: Double?
    var mapImage: UIImage?
    
    private enum CodingKeys: String, CodingKey {
        case rankPercentage
        case mapImage
    }
    
    init?(title: String, description: String?, entityType: String?, URL: String, type: DocumentType, rank: Double) {
        self.rankPercentage = rank
        super.init(title: title, description: description, entityType: entityType, URL: URL, type: type)
    }
    
    override func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(rankPercentage, forKey: .rankPercentage)
        if mapImage != nil {
            let imageData: Data = mapImage!.pngData()!
            let strBase64 = imageData.base64EncodedString(options: .lineLength64Characters)
            try container.encode(strBase64, forKey: .mapImage)
        }
        
        let superencoder = container.superEncoder()
        try super.encode(to: superencoder)
    }
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let superdecoder = try container.superDecoder()
        try super.init(from: superdecoder)
        
        rankPercentage = try container.decode(Double.self, forKey: .rankPercentage)
        do {
            let strBase64: String = try container.decode(String.self, forKey: .mapImage)
            let dataDecoded: Data = Data(base64Encoded: strBase64, options: .ignoreUnknownCharacters)!
            mapImage = UIImage(data: dataDecoded)
        } catch {
        }
    }
    
    //MARK: Visitable
    override func accept(visitor: DocumentVisitor) {
        visitor.process(document: self)
    }
}

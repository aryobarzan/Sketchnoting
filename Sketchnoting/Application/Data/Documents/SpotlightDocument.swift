//
//  SpotlightDocument.swift
//  Sketchnoting
//
//  Created by Aryobarzan on 16/07/2019.
//  Copyright © 2019 Aryobarzan. All rights reserved.
//

import UIKit

class SpotlightDocument: Document { // Out of date and currently unused
    
    var secondRankPercentage: Double?
    var label: String?
    var types: [String]?
    var wikiPageID: Double?
    var latitude: Double?
    var longitude: Double?
    var mapImage: UIImage?
    
    private enum CodingKeys: String, CodingKey {
        case secondRankPercentage
        case label
        case types = "types"
        case wikiPageID
        case latitude
        case longitude
        case mapImage
    }
    
    init?(title: String, description: String?, URL: String, type: DocumentType, rank: Double?, label: String?, types: [String]?, wikiPageID: Double?, latitude: Double?, longitude: Double?, mapImage: UIImage?) {
        self.secondRankPercentage = rank
        self.label = label
        self.types = types
        self.wikiPageID = wikiPageID
        self.latitude = latitude
        self.longitude = longitude
        self.mapImage = mapImage
        super.init(title: title, description: description, URL: URL, documentType: type)
    }
    
    override func encode(to encoder: Encoder) throws {
        try super.encode(to: encoder)
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(secondRankPercentage, forKey: .secondRankPercentage)
        try container.encode(label, forKey: .label)
        try container.encode(types, forKey: .types)
        try container.encode(wikiPageID, forKey: .wikiPageID)
        try container.encode(latitude, forKey: .latitude)
        try container.encode(longitude, forKey: .longitude)
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
        secondRankPercentage = try? container.decode(Double.self, forKey: .secondRankPercentage)
        label = try? container.decode(String.self, forKey: .label)
        types = try? container.decode([String].self, forKey: .types)
        wikiPageID = try? container.decode(Double.self, forKey: .wikiPageID)
        latitude = try? container.decode(Double.self, forKey: .latitude)
        longitude = try? container.decode(Double.self, forKey: .longitude)
        do {
            let strBase64: String = try container.decode(String.self, forKey: .mapImage)
            let dataDecoded: Data = Data(base64Encoded: strBase64, options: .ignoreUnknownCharacters)!
            mapImage = UIImage(data: dataDecoded)
        } catch {
            log.info("No map image found for this Spotlight document.")
        }
    }
    
    //MARK: Visitable
    override func accept(visitor: DocumentVisitor) {
        visitor.process(document: self)
    }
}

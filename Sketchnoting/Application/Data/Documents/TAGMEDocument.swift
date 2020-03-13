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
    }
    
    init?(title: String, description: String?, URL: String, type: DocumentType, spot: String?, categories: [String]?, wikiPageID: Double?) {
        self.spot = spot
        self.categories = categories
        self.wikiPageID = wikiPageID
        super.init(title: title, description: description, URL: URL, documentType: type)
    }
    
    override func encode(to encoder: Encoder) throws {
        try super.encode(to: encoder)
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(spot, forKey: .spot)
        try container.encode(categories, forKey: .categories)
        try container.encode(wikiPageID, forKey: .wikiPageID)
    }
    
    required init(from decoder: Decoder) throws {
        try super.init(from: decoder)
        
        let container = try decoder.container(keyedBy: CodingKeys.self)
        spot = try? container.decode(String.self, forKey: .spot)
        categories = try? container.decode([String].self, forKey: .categories)
        wikiPageID = try? container.decode(Double.self, forKey: .wikiPageID)
        
        loadMapImage()
    }
    
    //MARK: Visitable
    override func accept(visitor: DocumentVisitor) {
        visitor.process(document: self)
    }
    
    private func loadMapImage() {
        self.retrieveImage(type: .Map, completion: { result in
            switch result {
            case .success(let value):
                if value != nil {
                    log.info("Map image found for document \(self.title).")
                    DispatchQueue.main.async {
                        self.mapImage = value!
                    }
                }
            case .failure(_):
                log.error("No map image found for document \(self.title).")
            }
        })
    }
    
    override func reload() {
        loadMapImage()
        delegate?.documentHasChanged(document: self)
    }
}

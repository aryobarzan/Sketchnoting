//
//  ARDocument.swift
//  Sketchnoting
//
//  Created by Aryobarzan on 04/07/2020.
//  Copyright © 2020 Aryobarzan. All rights reserved.
//

import UIKit

class ARDocument: Document {
    
    var spot: String?
    var categories: [String]?
    var wikiPageID: Double?
    
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
    }
    
    //MARK: Visitable
    override func accept(visitor: DocumentVisitor) {
        visitor.process(document: self)
    }
    
    override func reload() {
        delegate?.documentHasChanged(document: self)
    }
}

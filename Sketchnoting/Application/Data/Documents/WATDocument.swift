//
//  WATDocument.swift
//  Sketchnoting
//
//  Created by Aryobarzan on 03/05/2020.
//  Copyright © 2020 Aryobarzan. All rights reserved.
//

import UIKit

class WATDocument: Document {
    
    var spot: String?
    var wikiPageID: Double?
    
    private enum CodingKeys: String, CodingKey {
        case spot
        case wikiPageID
    }
    
    init?(title: String, description: String?, URL: String, type: DocumentType, spot: String?, wikiPageID: Double?) {
        self.spot = spot
        self.wikiPageID = wikiPageID
        super.init(title: title, description: description, URL: URL, documentType: type)
    }
    
    override func encode(to encoder: Encoder) throws {
        try super.encode(to: encoder)
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(spot, forKey: .spot)
        try container.encode(wikiPageID, forKey: .wikiPageID)
    }
    
    required init(from decoder: Decoder) throws {
        try super.init(from: decoder)
        
        let container = try decoder.container(keyedBy: CodingKeys.self)
        spot = try? container.decode(String.self, forKey: .spot)
        wikiPageID = try? container.decode(Double.self, forKey: .wikiPageID)
    }
    
    override func getColor() -> UIColor {
        return #colorLiteral(red: 0.8549019694, green: 0.250980407, blue: 0.4784313738, alpha: 1)
    }
    
    override func getSymbol() -> UIImage? {
        return UIImage(systemName: "w.circle")
    }
    
    //MARK: Visitable
    override func accept(visitor: DocumentVisitor) {
        visitor.process(document: self)
    }

    override func reload() {
        delegate?.documentHasChanged(document: self)
    }
}

//
//  BioPortalDocument.swift
//  Sketchnoting
//
//  Created by Aryobarzan on 16/07/2019.
//  Copyright © 2019 Aryobarzan. All rights reserved.
//

import UIKit

class BioPortalDocument: Document {
    
    var prefLabel: String?
    var definition: String?
    
    private enum CodingKeys: String, CodingKey {
        case prefLabel
        case definition
    }
    
    init?(title: String, description: String?, entityType: String?, URL: String, type: DocumentType, prefLabel: String, definition: String) {
        self.prefLabel = prefLabel
        self.definition = definition
        super.init(title: title, description: description, entityType: entityType, URL: URL, type: type)
    }
    
    override func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(prefLabel, forKey: .prefLabel)
        try container.encode(definition, forKey: .definition)
        
        let superencoder = container.superEncoder()
        try super.encode(to: superencoder)
    }
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let superdecoder = try container.superDecoder()
        try super.init(from: superdecoder)
        
        prefLabel = try container.decode(String.self, forKey: .prefLabel)
        definition = try container.decode(String.self, forKey: .definition)
    }
    
    //MARK: Visitable
    override func accept(visitor: DocumentVisitor) {
        visitor.process(document: self)
    }
}

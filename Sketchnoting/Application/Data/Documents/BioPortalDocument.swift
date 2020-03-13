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
    
    init?(title: String, description: String?, URL: String, type: DocumentType, prefLabel: String, definition: String) {
        self.prefLabel = prefLabel
        self.definition = definition
        super.init(title: title, description: description, URL: URL, documentType: type)
    }
    
    override func encode(to encoder: Encoder) throws {
        try super.encode(to: encoder)
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(prefLabel, forKey: .prefLabel)
        try container.encode(definition, forKey: .definition)
    }
    
    required init(from decoder: Decoder) throws {
        try super.init(from: decoder)
        
        let container = try decoder.container(keyedBy: CodingKeys.self)
        prefLabel = try container.decode(String.self, forKey: .prefLabel)
        definition = try container.decode(String.self, forKey: .definition)
    }
    
    //MARK: Visitable
    override func accept(visitor: DocumentVisitor) {
        visitor.process(document: self)
    }
}

//
//  Document.swift
//  Sketchnoting
//
//  Created by Aryobarzan on 26/02/2019.
//  Copyright © 2019 Aryobarzan. All rights reserved.
//

import UIKit

enum DocumentType: String, Codable {
    case Wikipedia
    case Map
    case Babelfy
    case Other
}

class Document: Codable {
    
    var title: String
    var description: String?
    var URL: String
    var documentType: DocumentType
    
    enum CodingKeys: String, CodingKey {
        case title
        case description
        case URL
        case documentType
    }
    
    init?(title: String, description: String?, URL: String, type: DocumentType){
        guard !title.isEmpty && !URL.isEmpty else {
            return nil
        }
        self.title = title
        self.description = description
        self.URL = URL
        self.documentType = type
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(title, forKey: .title)
        try container.encode(description, forKey: .description)
        try container.encode(URL, forKey: .URL)
        try container.encode(documentType, forKey: .documentType)
    }
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        title = try container.decode(String.self, forKey: .title)
        description = try container.decode(String.self, forKey: .description)
        URL = try container.decode(String.self, forKey: .URL)
        documentType = DocumentType(rawValue: try container.decode(String.self, forKey: .documentType)) ?? .Other
    }
}

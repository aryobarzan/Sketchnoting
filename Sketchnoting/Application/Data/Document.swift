//
//  Document.swift
//  Sketchnoting
//
//  Created by Aryobarzan on 26/02/2019.
//  Copyright © 2019 Aryobarzan. All rights reserved.
//

import UIKit

// This enum is used to let the user know the type of a found document.
// Currently only the case Spotlight is used, as that is the only source for retrieving related documents.
enum DocumentType: String, Codable {
    case Wikipedia
    case Map
    case Babelfy
    case Spotlight
    case Other
}
// This class contains the information for a document that is related to a note's text.
// All of its properties are required, except for 'description', which is the abstract text of the found document.
// As this abstract text is manually fetched from the document's page source code via a regular expression, it may at times fail, hence why it is an optional property.
class Document: Codable {
    
    var title: String
    var description: String?
    var URL: String
    var documentType: DocumentType
    var rankPercentage: Double
    
    enum CodingKeys: String, CodingKey {
        case title
        case description
        case URL
        case documentType
        case rankPercentage
    }
    
    init?(title: String, description: String?, URL: String, type: DocumentType, rank: Double){
        guard !title.isEmpty && !URL.isEmpty else {
            return nil
        }
        self.title = title
        self.description = description
        self.URL = URL
        self.documentType = type
        self.rankPercentage = rank
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(title, forKey: .title)
        try container.encode(description, forKey: .description)
        try container.encode(URL, forKey: .URL)
        try container.encode(documentType, forKey: .documentType)
        try container.encode(rankPercentage, forKey: .rankPercentage)
    }
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        title = try container.decode(String.self, forKey: .title)
        description = try container.decode(String.self, forKey: .description)
        URL = try container.decode(String.self, forKey: .URL)
        documentType = DocumentType(rawValue: try container.decode(String.self, forKey: .documentType)) ?? .Other
        rankPercentage = try container.decode(Double.self, forKey: .rankPercentage)
    }
}

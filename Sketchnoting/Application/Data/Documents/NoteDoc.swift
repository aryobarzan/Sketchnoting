//
//  NoteDoc.swift
//  Sketchnoting
//
//  Created by Aryobarzan on 10/05/2020.
//  Copyright © 2020 Aryobarzan. All rights reserved.
//

//import UIKit
//
//enum DocMetadata: String {
//    case wiki_id = "wiki_id"
//    case tagme_rho = "tagme_rho"
//    case url = "url"
//}
//
//class NoteDoc: Codable, Equatable {
//    var title: String
//    var body: String
//    var metadata: Dictionary<String, AnyCodable>
//    var type: DocumentType
//    var spot: String
//    
//    var delegate: DocumentDelegate?
//    
//    init?(title: String, body: String, type: DocumentType, spot: String) {
//        self.title = title
//        self.body = body
//        self.metadata = Dictionary<String, Any>()
//        self.type = type
//        self.spot = spot
//    }
//    
//    func set(wikiID: Double) {
//        metadata[DocMetadata.wiki_id.rawValue] = wikiID
//    }
//    func set(rho: Double) {
//        metadata[DocMetadata.tagme_rho.rawValue] = rho
//    }
//    
//    func get(metadata: DocMetadata) -> Any? {
//        if let value = self.metadata[metadata.rawValue] {
//            return value
//        }
//        return nil
//    }
//    
//    // Codable
//    private enum CodingKeys: String, CodingKey {
//        case title = "title"
//        case body = "body"
//        case metadata = "metadata"
//        case type = "documentType"
//        case spot = "spot"
//    }
//    
//    func encode(to encoder: Encoder) throws {
//        var container = encoder.container(keyedBy: CodingKeys.self)
//        try container.encode(title, forKey: .title)
//        try container.encode(body, forKey: .body)
//        try container.encode(metadata, forKey: .metadata)
//        try container.encode(documentType, forKey: .documentType)
//    }
//    
//    required init(from decoder: Decoder) throws {
//        let container = try decoder.container(keyedBy: CodingKeys.self)
//        do {
//            title = try container.decode(String.self, forKey: CodingKeys.title)
//        } catch {
//            print(error)
//            title = ""
//        }
//        do {
//            description = try container.decode(String.self, forKey: .description)
//        } catch {
//            log.error(error)
//            log.error("Note description decoding failed.")
//            description = ""
//        }
//        URL = try container.decode(String.self, forKey: .URL)
//        documentType = DocumentType(rawValue: try container.decode(String.self, forKey: .documentType)) ?? .Other
//    }
//    
//    // Equatable
//    static func == (lhs: NoteDoc, rhs: NoteDoc) -> Bool {
//        <#code#>
//    }
//}

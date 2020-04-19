//
//  NoteTypedText.swift
//  Sketchnoting
//
//  Created by Aryobarzan on 14/04/2020.
//  Copyright © 2020 Aryobarzan. All rights reserved.
//

import UIKit
class NoteTypedText: Codable, Equatable {
    static let supportedLanguages = ["C", "Java", "Python", "Swift"]
    var text: String
    var codeLanguage: String
    var location: CGPoint
    var size: CGSize
    var id: String
    init(text: String, codeLanguage: String) {
        self.text = text
        self.codeLanguage = codeLanguage
        location = CGPoint(x: 150, y: 150)
        size = CGSize(width: 200, height: 200)
        id = UUID().uuidString
    }
    
    private enum CodingKeys: String, CodingKey {
        case location
        case size
        case text
        case codeLanguage
        case id
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        location = try container.decode(CGPoint.self, forKey: .location)
        size = try container.decode(CGSize.self, forKey: .size)
        text = try container.decode(String.self, forKey: .text)
        codeLanguage = try container.decode(String.self, forKey: .codeLanguage)
        id = try container.decode(String.self, forKey: .id)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(location, forKey: .location)
        try container.encode(size, forKey: .size)
        try container.encode(text, forKey: .text)
        try container.encode(codeLanguage, forKey: .codeLanguage)
        try container.encode(id, forKey: .id)
    }
    
    static func == (lhs: NoteTypedText, rhs: NoteTypedText) -> Bool {
        if (lhs.id == rhs.id) {
            return true
        }
        return false
    }
}

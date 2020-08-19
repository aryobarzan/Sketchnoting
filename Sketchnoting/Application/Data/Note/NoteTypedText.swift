//
//  NoteTypedText.swift
//  Sketchnoting
//
//  Created by Aryobarzan on 14/04/2020.
//  Copyright © 2020 Aryobarzan. All rights reserved.
//

import UIKit
class NoteTypedText: NoteLayer {
    static let supportedLanguages = ["C", "Java", "Python", "Swift"]
    var text: String
    var codeLanguage: String
    
    private enum CodingKeys: String, CodingKey {
        case text
        case codeLanguage
    }
    
    init?(text: String, codeLanguage: String) {
        self.text = text
        self.codeLanguage = codeLanguage
        let location = CGPoint(x: 150, y: 150)
        let size = CGSize(width: 200, height: 200)
        super.init(type: NoteLayerType.TypedText, location: location, size: size)
    }
    
    override func encode(to encoder: Encoder) throws {
        try super.encode(to: encoder)
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(text, forKey: .text)
        try container.encode(codeLanguage, forKey: .codeLanguage)
    }
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        text = try container.decode(String.self, forKey: .text)
        codeLanguage = try container.decode(String.self, forKey: .codeLanguage)
        try super.init(from: decoder)
    }
}

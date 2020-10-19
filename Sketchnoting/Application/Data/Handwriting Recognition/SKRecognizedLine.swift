//
//  SKRecognizedLine.swift
//  Sketchnoting
//
//  Created by Aryobarzan on 19/10/2020.
//  Copyright © 2020 Aryobarzan. All rights reserved.
//

import UIKit

class SKRecognizedLine: Codable, Equatable {
    var text: String
    var words: [SKRecognizedWord]
    
    init(text: String, words: [SKRecognizedWord]) {
        self.text = text
        self.words = words
    }
    
    static func == (lhs: SKRecognizedLine, rhs: SKRecognizedLine) -> Bool {
        return lhs.text == rhs.text &&
            lhs.words == rhs.words
    }
}

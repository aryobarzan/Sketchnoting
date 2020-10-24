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
    var renderBounds: CGRect
    
    init(text: String, words: [SKRecognizedWord], renderBounds: CGRect) {
        self.text = text
        self.words = words
        self.renderBounds = renderBounds
    }
    
    static func == (lhs: SKRecognizedLine, rhs: SKRecognizedLine) -> Bool {
        return lhs.text == rhs.text &&
            lhs.words == rhs.words && lhs.renderBounds == rhs.renderBounds
    }
}

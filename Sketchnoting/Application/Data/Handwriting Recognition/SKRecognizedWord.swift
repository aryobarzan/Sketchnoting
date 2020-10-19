//
//  SKRecognizedWord.swift
//  Sketchnoting
//
//  Created by Aryobarzan on 19/10/2020.
//  Copyright © 2020 Aryobarzan. All rights reserved.
//

import UIKit

class SKRecognizedWord: Codable, Equatable {
    var text: String
    var renderBounds: CGRect?
    
    init(text: String, renderBounds: CGRect?) {
        self.text = text
        self.renderBounds = renderBounds
    }
    
    static func == (lhs: SKRecognizedWord, rhs: SKRecognizedWord) -> Bool {
        return lhs.text == rhs.text &&
            lhs.renderBounds == rhs.renderBounds
    }
}

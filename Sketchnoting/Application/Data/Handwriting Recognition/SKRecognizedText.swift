//
//  SKRecognizedText.swift
//  Sketchnoting
//
//  Created by Aryobarzan on 19/10/2020.
//  Copyright © 2020 Aryobarzan. All rights reserved.
//

import UIKit

class SKRecognizedText: Codable, Equatable {
    var lines: [SKRecognizedLine]
    
    init(lines: [SKRecognizedLine] = [SKRecognizedLine]()) {
        self.lines = lines
    }
    
    public func getText() -> String {
        var text = ""
        for line in lines {
            text.append("\(line.text)\n")
        }
        return text
    }
    
    static func == (lhs: SKRecognizedText, rhs: SKRecognizedText) -> Bool {
        return lhs.lines == rhs.lines
    }
}

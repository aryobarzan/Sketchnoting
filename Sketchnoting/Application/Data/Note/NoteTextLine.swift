//
//  NoteTextLine.swift
//  Sketchnoting
//
//  Created by Aryobarzan on 07/02/2020.
//  Copyright © 2020 Aryobarzan. All rights reserved.
//

import UIKit

struct NoteTextLine: Codable {
    var text: String
    var elements: [NoteTextElement]
    var frame: CGRect
    init(text: String, elements: [NoteTextElement], frame: CGRect) {
        self.text = text
        self.elements = elements
        self.frame = frame
    }
}

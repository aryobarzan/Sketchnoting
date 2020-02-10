//
//  NoteTextBlock.swift
//  Sketchnoting
//
//  Created by Aryobarzan on 07/02/2020.
//  Copyright © 2020 Aryobarzan. All rights reserved.
//

import UIKit

struct NoteTextBlock: Codable {
    var text: String
    var lines: [NoteTextLine]
    var frame: CGRect
    init(text: String, lines: [NoteTextLine], frame: CGRect) {
        self.text = text
        self.lines = lines
        self.frame = frame
    }
}

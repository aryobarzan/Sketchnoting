//
//  NoteTextComplete.swift
//  Sketchnoting
//
//  Created by Aryobarzan on 07/02/2020.
//  Copyright © 2020 Aryobarzan. All rights reserved.
//

import UIKit

struct NoteTextComplete: Codable {
    var text: String
    var blocks: [NoteTextBlock]
    init(text: String, blocks: [NoteTextBlock]) {
        self.text = text
        self.blocks = blocks
    }
}

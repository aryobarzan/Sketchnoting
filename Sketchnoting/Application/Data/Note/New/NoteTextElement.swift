//
//  NoteTextElement.swift
//  Sketchnoting
//
//  Created by Aryobarzan on 07/02/2020.
//  Copyright © 2020 Aryobarzan. All rights reserved.
//

import UIKit

struct NoteTextElement: Codable {
    var text: String
    var frame: CGRect
    init(text: String, frame: CGRect) {
        self.text = text
        self.frame = frame
    }
}

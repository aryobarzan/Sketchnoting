//
//  NoteText.swift
//  Sketchnoting
//
//  Created by Aryobarzan on 07/02/2020.
//  Copyright © 2020 Aryobarzan. All rights reserved.
//

import UIKit
import Firebase

struct NoteText: Codable {
    let spellchecked: String
    var corrected: String
    
    var text: String
    var blocks: [NoteTextBlock]
    init(visionText: VisionText, spellcheck: Bool) {
        self.text = visionText.text
        if spellcheck {
            self.spellchecked = OCRHelper.postprocess(text: text)
        }
        else {
            self.spellchecked = text
        }
        self.corrected = spellchecked
        self.blocks = NoteText.createVisionTextWrapper(visionText: visionText)
    }
    
    private static func createVisionTextWrapper(visionText: VisionText) -> [NoteTextBlock] {
        var blocks = [NoteTextBlock]()
        for block in visionText.blocks {
            var lines = [NoteTextLine]()
            for line in block.lines {
                var elements = [NoteTextElement]()
                for element in line.elements {
                    elements.append(NoteTextElement(text: element.text, frame: element.frame))
                }
                lines.append(NoteTextLine(text: line.text, elements: elements, frame: line.frame))
            }
            blocks.append(NoteTextBlock(text: block.text, lines: lines, frame: block.frame))
        }
        return blocks
    }
}

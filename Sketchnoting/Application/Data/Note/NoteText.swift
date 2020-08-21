//
//  NoteText.swift
//  Sketchnoting
//
//  Created by Aryobarzan on 07/02/2020.
//  Copyright © 2020 Aryobarzan. All rights reserved.
//

import UIKit
import Firebase
import MLKit

struct NoteText: Codable {
    let spellchecked: String
    var corrected: String
    
    var text: String
    var blocks: [NoteTextBlock]
    init(visionText: Firebase.VisionText, spellcheck: Bool) {
        self.text = visionText.text
        self.spellchecked = text
        self.corrected = spellchecked
        self.blocks = NoteText.createVisionTextWrapper(visionText: visionText)
    }
    init(visionText: MLKit.Text, spellcheck: Bool) {
        self.text = visionText.text
        self.spellchecked = text
        self.corrected = spellchecked
        self.blocks = NoteText.createVisionTextWrapper(visionText: visionText)
    }
    
    private static func createVisionTextWrapper(visionText: Firebase.VisionText) -> [NoteTextBlock] {
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
    
    private static func createVisionTextWrapper(visionText: MLKit.Text) -> [NoteTextBlock] {
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

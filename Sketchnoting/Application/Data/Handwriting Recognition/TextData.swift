//
//  TextData.swift
//  Sketchnoting
//
//  Created by Aryobarzan on 22/07/2019.
//  Copyright © 2019 Aryobarzan. All rights reserved.
//

import UIKit
import Firebase

class TextData: NSObject, NSCoding {
    let visionTextWrapper: VisionTextWrapper!
    let paths: [CGRect]!
    
    let original: String!
    let spellchecked: String!
    var corrected: String?
    
    let imageSize : CGSize!
    
    init(visionText: VisionText, original: String, paths: [CGRect], imageSize: CGSize, spellcheck: Bool) {
        self.paths = paths
        self.original = original
        if spellcheck {
            self.spellchecked = OCRHelper.postprocess(text: original)
        }
        else {
            self.spellchecked = original
        }
        self.imageSize = imageSize
        self.visionTextWrapper = TextData.createVisionTextWrapper(visionText: visionText)
    }
    
    private static func createVisionTextWrapper(visionText: VisionText) -> VisionTextWrapper {
        var blocks = [VisionTextBlockWrapper]()
        for block in visionText.blocks {
            var lines = [VisionTextLineWrapper]()
            for line in block.lines {
                var elements = [VisionTextElementWrapper]()
                for element in line.elements {
                    elements.append(VisionTextElementWrapper(text: element.text, frame: element.frame))
                }
                lines.append(VisionTextLineWrapper(text: line.text, elements: elements, frame: line.frame))
            }
            blocks.append(VisionTextBlockWrapper(text: block.text, lines: lines, frame: block.frame))
        }
        return VisionTextWrapper(text: visionText.text, blocks: blocks)
    }
    
    //MARK: Decode / Encode
    enum Keys: String {
        case visionTextWrapper = "VisionTextWrapper"
        case paths = "Paths"
        case original = "Original"
        case spellchecked = "Spellchecked"
        case corrected = "Corrected"
        case imageSize = "ImageSize"
    }

    func encode(with aCoder: NSCoder) {
        aCoder.encode(paths, forKey: Keys.paths.rawValue)
        aCoder.encode(original, forKey: Keys.original.rawValue)
        aCoder.encode(spellchecked, forKey: Keys.spellchecked.rawValue)
        aCoder.encode(corrected, forKey: Keys.corrected.rawValue)
        aCoder.encode(visionTextWrapper, forKey: Keys.visionTextWrapper.rawValue)
        aCoder.encode(imageSize, forKey: Keys.imageSize.rawValue)
    }
    
    required init?(coder aDecoder: NSCoder) {
        paths = aDecoder.decodeObject(forKey: Keys.paths.rawValue) as? [CGRect]
        original = aDecoder.decodeObject(forKey: Keys.original.rawValue) as? String
        spellchecked = aDecoder.decodeObject(forKey: Keys.spellchecked.rawValue) as? String
        corrected = aDecoder.decodeObject(forKey: Keys.corrected.rawValue) as? String
        visionTextWrapper = aDecoder.decodeObject(forKey: Keys.visionTextWrapper.rawValue) as? VisionTextWrapper
        imageSize = aDecoder.decodeObject(forKey: Keys.imageSize.rawValue) as? CGSize
    }
}

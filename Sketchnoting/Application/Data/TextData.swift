//
//  TextData.swift
//  Sketchnoting
//
//  Created by Aryobarzan on 22/07/2019.
//  Copyright © 2019 Aryobarzan. All rights reserved.
//

import UIKit
import Firebase

class TextData: NSCoding {
    let visionText: VisionText!
    let paths: [CGRect]!
    
    let original: String!
    let spellchecked: String!
    var corrected: String?
    
    init(visionText: VisionText, original: String, paths: [CGRect]) {
        self.visionText = visionText
        self.paths = paths
        self.original = original
        self.spellchecked = OCRHelper.postprocess(text: original)
    }
    
    //MARK: Decode / Encode
    enum Keys: String {
        case visionText = "VisionText"
        case paths = "Paths"
        case original = "Original"
        case spellchecked = "Spellchecked"
        case corrected = "Corrected"
    }

    func encode(with aCoder: NSCoder) {
        aCoder.encode(visionText, forKey: Keys.visionText.rawValue)
        aCoder.encode(paths, forKey: Keys.paths.rawValue)
        aCoder.encode(original, forKey: Keys.original.rawValue)
        aCoder.encode(spellchecked, forKey: Keys.spellchecked.rawValue)
        aCoder.encode(corrected, forKey: Keys.corrected.rawValue)
    }
    
    required init?(coder aDecoder: NSCoder) {
        visionText = aDecoder.decodeObject(forKey: Keys.visionText.rawValue) as! VisionText
        paths = aDecoder.decodeObject(forKey: Keys.paths.rawValue) as! [CGRect]
        original = aDecoder.decodeObject(forKey: Keys.original.rawValue) as! String
        spellchecked = aDecoder.decodeObject(forKey: Keys.spellchecked.rawValue) as! String
        corrected = aDecoder.decodeObject(forKey: Keys.corrected.rawValue) as? String
    }
}

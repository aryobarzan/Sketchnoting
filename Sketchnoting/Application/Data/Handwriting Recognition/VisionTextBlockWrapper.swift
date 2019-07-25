//
//  VisionTextBlockWrapper.swift
//  Sketchnoting
//
//  Created by Aryobarzan on 25/07/2019.
//  Copyright © 2019 Aryobarzan. All rights reserved.
//

import UIKit

class VisionTextBlockWrapper: NSObject, NSCoding {
    var text: String!
    var lines: [VisionTextLineWrapper]!
    var frame: CGRect!
    init(text: String, lines: [VisionTextLineWrapper], frame: CGRect) {
        self.text = text
        self.lines = lines
        self.frame = frame
    }
    //MARK: Decode / Encode
    enum Keys: String {
        case text = "Text"
        case lines = "Lines"
        case frame = "Frame"
    }
    func encode(with aCoder: NSCoder) {
        aCoder.encode(text, forKey: Keys.text.rawValue)
        aCoder.encode(lines, forKey: Keys.lines.rawValue)
        aCoder.encode(frame, forKey: Keys.frame.rawValue)
    }
    
    required init?(coder aDecoder: NSCoder) {
        text = aDecoder.decodeObject(forKey: Keys.text.rawValue) as? String
        lines = aDecoder.decodeObject(forKey: Keys.lines.rawValue) as? [VisionTextLineWrapper]
        frame = aDecoder.decodeObject(forKey: Keys.frame.rawValue) as? CGRect
    }
}

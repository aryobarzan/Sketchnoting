//
//  VisionTextLineWrapper.swift
//  Sketchnoting
//
//  Created by Aryobarzan on 25/07/2019.
//  Copyright © 2019 Aryobarzan. All rights reserved.
//

import UIKit

class VisionTextLineWrapper: NSObject, NSCoding {
    var text: String!
    var elements: [VisionTextElementWrapper]!
    var frame: CGRect!
    init(text: String, elements: [VisionTextElementWrapper], frame: CGRect) {
        self.text = text
        self.elements = elements
        self.frame = frame
    }
    //MARK: Decode / Encode
    enum Keys: String {
        case text = "Text"
        case elements = "Elements"
        case frame = "Frame"
    }
    func encode(with aCoder: NSCoder) {
        aCoder.encode(text, forKey: Keys.text.rawValue)
        aCoder.encode(elements, forKey: Keys.elements.rawValue)
        aCoder.encode(frame, forKey: Keys.frame.rawValue)
    }
    
    required init?(coder aDecoder: NSCoder) {
        text = aDecoder.decodeObject(forKey: Keys.text.rawValue) as? String
        elements = aDecoder.decodeObject(forKey: Keys.elements.rawValue) as? [VisionTextElementWrapper]
        frame = aDecoder.decodeObject(forKey: Keys.frame.rawValue) as? CGRect
    }
}

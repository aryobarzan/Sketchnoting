//
//  VisionTextElementWrapper.swift
//  Sketchnoting
//
//  Created by Aryobarzan on 25/07/2019.
//  Copyright © 2019 Aryobarzan. All rights reserved.
//

import UIKit

class VisionTextElementWrapper: NSObject, NSCoding {
    var text: String!
    var frame: CGRect!
    init(text: String, frame: CGRect) {
        self.text = text
        self.frame = frame
    }
    //MARK: Decode / Encode
    enum Keys: String {
        case text = "Text"
        case frame = "Frame"
    }
    func encode(with aCoder: NSCoder) {
        aCoder.encode(text, forKey: Keys.text.rawValue)
        aCoder.encode(frame, forKey: Keys.frame.rawValue)
    }
    
    required init?(coder aDecoder: NSCoder) {
        text = aDecoder.decodeObject(forKey: Keys.text.rawValue) as? String
        frame = aDecoder.decodeObject(forKey: Keys.frame.rawValue) as? CGRect
    }
}


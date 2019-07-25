//
//  VisionTextWrapper.swift
//  Sketchnoting
//
//  Created by Aryobarzan on 25/07/2019.
//  Copyright © 2019 Aryobarzan. All rights reserved.
//

import UIKit

class VisionTextWrapper: NSObject, NSCoding {
    var text: String!
    var blocks: [VisionTextBlockWrapper]!
    
    init(text: String, blocks: [VisionTextBlockWrapper]) {
        self.text = text
        self.blocks = blocks
    }
    //MARK: Decode / Encode
    enum Keys: String {
        case text = "Text"
        case blocks = "Blocks"
    }
    func encode(with aCoder: NSCoder) {
        aCoder.encode(text, forKey: Keys.text.rawValue)
        aCoder.encode(blocks, forKey: Keys.blocks.rawValue)
    }
    
    required init?(coder aDecoder: NSCoder) {
        text = aDecoder.decodeObject(forKey: Keys.text.rawValue) as? String
        blocks = aDecoder.decodeObject(forKey: Keys.blocks.rawValue) as? [VisionTextBlockWrapper]
    }
    
    
}

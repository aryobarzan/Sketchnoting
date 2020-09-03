//
//  NoteImage.swift
//  Sketchnoting
//
//  Created by Aryobarzan on 11/04/2020.
//  Copyright © 2020 Aryobarzan. All rights reserved.
//

import UIKit

class NoteImage: NoteLayer {
    
    var image: UIImage
    
    private enum CodingKeys: String, CodingKey {
        case image
    }
    
    init(image: UIImage, location: CGPoint = CGPoint(x: 50, y: 50), size: CGSize? = nil) {
        self.image = image
        if let size = size {
            super.init(type: NoteLayerType.Image, location: location, size: size)
        }
        else {
            super.init(type: NoteLayerType.Image, location: location, size: CGSize(width: 0.25 * image.size.width, height: 0.25 * image.size.height))
        }
    }
    
    override func encode(to encoder: Encoder) throws {
        try super.encode(to: encoder)
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(image, forKey: .image, quality: .png)
    }
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        image = try container.decode(UIImage.self, forKey: .image)
        try super.init(from: decoder)
    }
}

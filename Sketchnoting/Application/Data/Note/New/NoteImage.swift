//
//  NoteImage.swift
//  Sketchnoting
//
//  Created by Aryobarzan on 11/04/2020.
//  Copyright © 2020 Aryobarzan. All rights reserved.
//

import UIKit

class NoteImage: Codable, Equatable {
    
    var image: UIImage
    var location: CGPoint
    var size: CGSize
    var id: String
    init(image: UIImage) {
        self.image = image
        location = CGPoint(x: 50, y: 50)
        size = CGSize(width: 0.25 * image.size.width, height: 0.25 * image.size.height)
        id = UUID().uuidString
    }
    
    private enum CodingKeys: String, CodingKey {
        case location
        case size
        case image
        case id
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        location = try container.decode(CGPoint.self, forKey: .location)
        size = try container.decode(CGSize.self, forKey: .size)
        image = try container.decode(UIImage.self, forKey: .image)
        id = try container.decode(String.self, forKey: .id)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(location, forKey: .location)
        try container.encode(size, forKey: .size)
        try container.encode(image, forKey: .image, quality: .png)
        try container.encode(id, forKey: .id)
    }
    
    static func == (lhs: NoteImage, rhs: NoteImage) -> Bool {
        if (lhs.id == rhs.id) {
            return true
        }
        return false
    }
}

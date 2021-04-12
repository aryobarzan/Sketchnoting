//
//  Tag.swift
//  Sketchnoting
//
//  Created by Aryobarzan on 12/09/2019.
//  Copyright © 2019 Aryobarzan. All rights reserved.
//

import UIKit

public struct Tag: Equatable, Codable {
    
    var title: String!
    var color: UIColor!
    
    enum CodingKeys: String, CodingKey {
        case title
        case colorRed
        case colorGreen
        case colorBlue
    }
    
    init(title: String, color: UIColor) {
        self.title = title
        self.color = color
    }
    
    public static func == (lhs: Tag, rhs: Tag) -> Bool {
        if lhs.title == rhs.title {
            return true
        }
        return false
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        title = try? container.decode(String.self, forKey: .title)
        if title == nil || title.isEmpty {
            title = "Untitled Tag"
        }
        let redValue = try? container.decode(CGFloat.self, forKey: .colorRed)
        let greenValue = try? container.decode(CGFloat.self, forKey: .colorGreen)
        let blueValue = try? container.decode(CGFloat.self, forKey: .colorBlue)
        color = UIColor(red: redValue ?? 0.0, green: greenValue ?? 0.0, blue: blueValue ?? 0.0, alpha: 1.0)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(title, forKey: .title)
        try container.encode(color.redValue, forKey: .colorRed)
        try container.encode(color.greenValue, forKey: .colorGreen)
        try container.encode(color.blueValue, forKey: .colorBlue)
    }
}

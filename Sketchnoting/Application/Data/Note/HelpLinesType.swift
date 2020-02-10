//
//  HelpLinesType.swift
//  Sketchnoting
//
//  Created by Aryobarzan on 07/02/2020.
//  Copyright © 2020 Aryobarzan. All rights reserved.
//

import UIKit

public enum HelpLinesType: Codable {
    case None
    case Horizontal
    case Grid
    
    enum Key: CodingKey {
        case rawValue
    }
    
    enum CodingError: Error {
        case unknownValue
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: Key.self)
        let rawValue = try container.decode(Int.self, forKey: .rawValue)
        switch rawValue {
        case 0:
            self = .None
        case 1:
            self = .Horizontal
        case 2:
            self = .Grid
        default:
            throw CodingError.unknownValue
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: Key.self)
        switch self {
        case .None:
            try container.encode(0, forKey: .rawValue)
        case .Horizontal:
            try container.encode(1, forKey: .rawValue)
        case .Grid:
            try container.encode(2, forKey: .rawValue)
        }
    }
}


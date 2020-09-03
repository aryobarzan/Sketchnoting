//
//  NoteLayer.swift
//  Sketchnoting
//
//  Created by Aryobarzan on 19/08/2020.
//  Copyright © 2020 Aryobarzan. All rights reserved.
//

import UIKit

enum NoteLayerType: String, Codable, CaseIterable {
    case Image
    case TypedText
}

class NoteLayer: Codable, Equatable, Hashable {
    
    var type: NoteLayerType
    var location: CGPoint
    var size: CGSize
    var id: String
    
    private enum CodingKeys: String, CodingKey {
        case type = "type"
        case location = "location"
        case size = "size"
        case id = "id"
    }
    
    init(type: NoteLayerType, location: CGPoint, size: CGSize){
        self.type = type
        self.location = location
        self.size = size
        self.id = UUID().uuidString
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type, forKey: .type)
        try container.encode(location, forKey: .location)
        try container.encode(size, forKey: .size)
        try container.encode(id, forKey: .id)
    }
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        location = try container.decode(CGPoint.self, forKey: CodingKeys.location)
        size = try container.decode(CGSize.self, forKey: CodingKeys.size)
        id = try container.decode(String.self, forKey: CodingKeys.id)
        type = NoteLayerType(rawValue: try container.decode(String.self, forKey: .type)) ?? .TypedText
    }
    
    static func == (lhs: NoteLayer, rhs: NoteLayer) -> Bool {
        return lhs.id == rhs.id
    }
       
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

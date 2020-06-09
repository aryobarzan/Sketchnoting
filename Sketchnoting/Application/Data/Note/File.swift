//
//  File.swift
//  Sketchnoting
//
//  Created by Aryobarzan on 07/02/2020.
//  Copyright © 2020 Aryobarzan. All rights reserved.
//

import UIKit

class File: Codable, Comparable, Equatable, Hashable {
    var id: String
    private var name: String
    var creationDate: Date
    var updateDate: Date
    var parent: String? // ID
    
    init(name: String, parent: String?) {
        self.id = UUID().uuidString
        self.name = name
        self.creationDate = Date.init(timeIntervalSinceNow: 0)
        self.updateDate = Date.init(timeIntervalSinceNow: 0)
        self.parent = parent
    }
    
    // Codable
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case creationDate
        case updateDate
        case parent
    }
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(creationDate.timeIntervalSince1970, forKey: .creationDate)
        try container.encode(updateDate.timeIntervalSince1970, forKey: .updateDate)
        if parent != nil {
            try container.encode(parent, forKey: .parent)
        }
        log.info("File " + self.id + " encoded.")

    }
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        if name.isEmpty {
            name = "Untitled"
        }
        creationDate = Date(timeIntervalSince1970: try container.decode(TimeInterval.self, forKey: .creationDate))
        updateDate = Date(timeIntervalSince1970: try container.decode(TimeInterval.self, forKey: .updateDate))
        parent = try? container.decode(String.self, forKey: .parent)
        log.info("File " + self.id + " decoded.")
    }
    
    //
    public func getName() -> String {
        return name
    }
    
    func setName(name: String) {
        if name.isEmpty || name.count < 1 {
            self.name = "Untitled"
        }
        else {
            self.name = name
        }
    }
    
    func setUpdateDate() {
        self.updateDate = Date.init(timeIntervalSinceNow: 0)
    }
    
    public func getPreviewImage(completion: @escaping (UIImage) -> Void) {
        UITraitCollection(userInterfaceStyle: .light).performAsCurrent {
            completion(UIImage(systemName: "folder.fill")!)
        }
    }
    
    public func encodeFileAsData() -> Data? {
        var data = [Data]()
        // Encode metadata
        let metaDataEncoder = JSONEncoder()
        if let encodedMetaData = try? metaDataEncoder.encode(self) {
            data.append(encodedMetaData)
            log.info("File \(self.getName()) encoded.")
        }
        else {
            log.error("Encoding failed for file " + self.getName() + ".")
        }
        let dataEncoded = try? NSKeyedArchiver.archivedData(withRootObject: data, requiringSecureCoding: false)
        return dataEncoded
    }
    
    static func == (lhs: File, rhs: File) -> Bool {
        if lhs.id == rhs.id {
            return true
        }
        return false
    }
    
    static func < (lhs: File, rhs: File) -> Bool {
        return lhs.creationDate < rhs.creationDate
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

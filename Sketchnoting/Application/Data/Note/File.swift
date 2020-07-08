//
//  File.swift
//  Sketchnoting
//
//  Created by Aryobarzan on 07/02/2020.
//  Copyright © 2020 Aryobarzan. All rights reserved.
//

import UIKit

class File: Codable, Equatable, Hashable {
    private var name: String
    
    init(name: String) {
        self.name = name
    }
    
    // Codable
    enum CodingKeys: String, CodingKey {
        case name
    }
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        log.info("File " + self.name + " encoded.")
    }
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        if name.isEmpty {
            name = "Untitled"
        }
        log.info("File " + self.name + " decoded.")
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
        if lhs.name == rhs.name {
            return true
        }
        return false
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(name)
    }
}

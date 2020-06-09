//
//  Folder.swift
//  Sketchnoting
//
//  Created by Aryobarzan on 07/02/2020.
//  Copyright © 2020 Aryobarzan. All rights reserved.
//

import UIKit

class Folder: File {

    private var children: [String] // Their IDs
    
    override init(name: String, parent: String?) {
        self.children = [String]()
        super.init(name: name, parent: parent)
    }
    
    // Codable
    private enum FolderCodingKeys: String, CodingKey {
        case children = "children"
    }
    override func encode(to encoder: Encoder) throws {
        try super.encode(to: encoder)
        var container = encoder.container(keyedBy: FolderCodingKeys.self)
        try container.encode(children, forKey: .children)
        log.info("Folder " + self.id + " encoded.")

    }
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: FolderCodingKeys.self)
        children = try container.decode([String].self, forKey: .children)
        try super.init(from: decoder)
        log.info("Folder " + self.getName() + " decoded.")
    }
    
    // Methods
    public func addChild(file: File) {
        if !children.contains(file.id) {
            children.append(file.id)
            file.parent = self.id
        }
    }
    
    public func removeChild(file: File) {
        if children.contains(file.id) {
            children.removeAll{$0 == file.id}
            file.parent = nil
        }
    }
    
    public func getChildren() -> [String] {
        return children
    }
}

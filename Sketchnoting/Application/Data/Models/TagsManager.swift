//
//  TagsManager.swift
//  Sketchnoting
//
//  Created by Aryobarzan on 12/09/2019.
//  Copyright © 2019 Aryobarzan. All rights reserved.
//

import UIKit

class TagsManager {
    static var tags: [Tag] = getTags()
    public static func getTags() -> [Tag] {
        let decoder = JSONDecoder()
        
        var tags = [Tag]()
        for (key, _) in UserDefaults.tags.dictionaryRepresentation() {
            if let data = UserDefaults.tags.data(forKey: key),
                let loadedTag = try? decoder.decode(Tag.self, from: data) {
                tags.append(loadedTag)
            }
        }
        return tags
    }
    public static func reload() {
        self.tags = getTags()
    }
    public static func add(tag: Tag) {
        let encoder = JSONEncoder()
        
        if !self.tags.contains(tag) {
            self.tags.append(tag)
            if let encoded = try? encoder.encode(tag) {
                UserDefaults.tags.set(encoded, forKey: tag.title)
                log.info("Tag \(String(describing: tag.title)) added.")
            }
            else {
                log.error("Failed adding new tag \(String(describing: tag.title)).")
            }
        }
    }
    public static func delete(tag: Tag) {
        if self.tags.contains(tag) {
            tags.removeAll{$0 == tag}
            UserDefaults.tags.removeObject(forKey: tag.title)
        }
    }
}

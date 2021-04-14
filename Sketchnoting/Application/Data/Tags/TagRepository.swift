//
//  TagRepository.swift
//  Sketchnoting
//
//  Created by Aryobarzan on 12/04/2021.
//  Copyright © 2021 Aryobarzan. All rights reserved.
//

import UIKit

public class TagRepository: Codable {
        
    private var tags: [Tag]!
    private var noteTags: [String : [String]]!
    
    enum CodingKeys: String, CodingKey {
        case tags
        case noteTags
    }
    
    init(tags: [Tag] = [Tag](), noteTags: [String : [String]] = [String : [String]]()) {
        self.tags = tags
        self.noteTags = noteTags
    }
    
    required public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        tags = try? container.decode([Tag].self, forKey: .tags)
        noteTags = try? container.decode([String : [String]].self, forKey: .noteTags)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(tags, forKey: .tags)
        try container.encode(noteTags, forKey: .noteTags)
    }
    
    //
    
    func add(tag: Tag) -> Bool {
        if !tags.contains(tag) {
            tags.append(tag)
            return true
        }
        return false
    }
    
    func delete(tag: Tag) -> Bool {
        if tags.contains(tag) {
            tags.remove(object: tag)
            for (key, values) in noteTags {
                noteTags[key] = values.filter {$0 != tag.title}
            }
            return true
        }
        return false
    }
    
    func add(tag: Tag, for note: Note) -> Bool {
        // In case tag itself is not yet stored, store it
        _ = self.add(tag: tag)
        // Add tag for note
        var tagsForNote = noteTags[note.getID()] ?? [String]()
        if !tagsForNote.contains(tag.title) {
            tagsForNote.append(tag.title)
            noteTags[note.getID()] = tagsForNote
            return true
        }
        return false
    }
    
    func delete(tag: Tag, for note: Note) -> Bool {
        var tagsForNote = noteTags[note.getID()] ?? [String]()
        if !tagsForNote.isEmpty && tagsForNote.contains(tag.title) {
            tagsForNote.remove(object: tag.title)
            return true
        }
        return false
    }
    
    func set(tags: [Tag], for note: Note) {
        for tag in tags {
            _ = add(tag: tag)
        }
        noteTags[note.getID()] = tags.map{$0.title}
    }
    
    func getTags(sorted: Bool = true) -> [Tag] {
        return tags.sorted {tag1, tag2 in
            tag1.title < tag2.title
        }
    }
    
    func getTags(for note: Note) -> [Tag] {
        if let tagsForNote = noteTags[note.getID()] {
            return getTags().filter { tagsForNote.contains($0.title)}
        }
        return [Tag]()
    }
}

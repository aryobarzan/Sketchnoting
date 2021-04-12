//
//  TagsManager.swift
//  Sketchnoting
//
//  Created by Aryobarzan on 12/09/2019.
//  Copyright © 2019 Aryobarzan. All rights reserved.
//

import UIKit

class TagsManager {
    private var tagRepository: TagRepository
    static var filterTags = [Tag]()
    
    init() {
        self.tagRepository = NeoLibrary.loadTagRepository()
    }
    
    public func reload() {
        self.tagRepository = NeoLibrary.loadTagRepository()
    }
    
    public func getTags(for note: Note? = nil) -> [Tag] {
        if let note = note {
            return tagRepository.getTags(for: note)
        }
        else {
            return tagRepository.getTags()
        }
    }

    public func add(tag: Tag) {
        _ = tagRepository.add(tag: tag)
        NeoLibrary.save(tagRepository: tagRepository)
    }
    
    public func delete(tag: Tag) {
        _ = tagRepository.delete(tag: tag)
        NeoLibrary.save(tagRepository: tagRepository)
        if TagsManager.filterTags.contains(tag) {
            TagsManager.filterTags.remove(object: tag)
        }
    }
    
    public func set(tags: [Tag], for note: Note) {
        tagRepository.set(tags: tags, for: note)
        NeoLibrary.save(tagRepository: tagRepository)
    }
}

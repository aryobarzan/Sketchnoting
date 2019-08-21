//
//  NotesManager.swift
//  Sketchnoting
//
//  Created by Aryobarzan on 28/05/2019.
//  Copyright © 2019 Aryobarzan. All rights reserved.
//

import UIKit

class NotesManager {

    static let shared = NotesManager()
    
    private init() {
    }
    
    // MARK : Saving to and loading from disk
    
    // MARK : Updating data
    public func update(note: Sketchnote, pathArray: NSMutableArray?) {
        note.paths = pathArray
        note.save()
    }
}

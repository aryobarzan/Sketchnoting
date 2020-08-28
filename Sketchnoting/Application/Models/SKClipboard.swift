//
//  SKClipboard.swift
//  Sketchnoting
//
//  Created by Aryobarzan on 20/06/2020.
//  Copyright © 2020 Aryobarzan. All rights reserved.
//

import UIKit

class SKClipboard {
    private static var note: Note?
    private static var page: NotePage?
    private static var noteLayer: NoteLayer?
            
    public static func clear() {
        self.note = nil
        self.page = nil
        self.noteLayer = nil
    }
    
    public static func hasItems() -> Bool {
        if self.note != nil || self.page != nil || self.noteLayer != nil {
            return true
        }
        return false
    }
    
    public static func copy(note: Note) {
        self.note = note
    }
    
    public static func copy(page: NotePage) {
        self.page = page
    }
    
    public static func copy(noteLayer: NoteLayer) {
        self.noteLayer = noteLayer
    }
    
    // Missing: rework
    public static func getNote() -> Note? {
        return note
    }
    
    public static func getPage() -> NotePage? {
        return page
    }
    
    public static func getNoteLayer() -> NoteLayer? {
        return noteLayer
    }
}

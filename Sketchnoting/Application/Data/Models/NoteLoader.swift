//
//  NoteLoader.swift
//  Sketchnoting
//
//  Created by Aryobarzan on 23/07/2019.
//  Copyright © 2019 Aryobarzan. All rights reserved.
//

import UIKit

class NoteLoader {
    public static func loadSketchnotes() -> [Sketchnote]? {
        let decoder = JSONDecoder()
        
        var sketchnotes = [Sketchnote]()
        for (key, _) in UserDefaults.sketchnotes.dictionaryRepresentation() {
            if let data = UserDefaults.sketchnotes.data(forKey: key),
                let loadedSketchnote = try? decoder.decode(Sketchnote.self, from: data) {
                log.info("Note \(key) loaded.")
                sketchnotes.append(loadedSketchnote)
            }
        }
        if SettingsManager.noteSortingByNewest() {
            log.info("Sorting notes by newest first.")
            return sketchnotes.sorted(by: { (note0: Sketchnote, note1: Sketchnote) -> Bool in
                return note0 > note1
            })
        }
        else {
            return sketchnotes.sorted()
        }
    }
    public static func loadSketchnote(id: String) -> Sketchnote? {
        let decoder = JSONDecoder()
        
        var sketchnote: Sketchnote?
        if let data = UserDefaults.sketchnotes.data(forKey: id), let loadedSketchnote = try? decoder.decode(Sketchnote.self, from: data) {
            sketchnote = loadedSketchnote
            log.info("Specific note \(id) loaded.")
        }
        return sketchnote
    }
}

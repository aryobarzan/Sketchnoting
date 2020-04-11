//
//  ImportHelper.swift
//  Sketchnoting
//
//  Created by Aryobarzan on 08/04/2020.
//  Copyright © 2020 Aryobarzan. All rights reserved.
//

import UIKit

class ImportHelper {
    static func importItems(urls: [URL], n: NoteX?) -> ([NoteX], [UIImage]) {
        var notes = [NoteX]()
        var images = [UIImage]()
        for url in urls {
            var isNote = false
            do {
                let data = try Data(contentsOf: url)
                if let decodedNote = SKFileManager.decodeNoteFromData(data: data) {
                    notes.append(decodedNote)
                    isNote = true
                }
                if !isNote {
                    if let decodedImage = UIImage(data: data) {
                        images.append(decodedImage)
                    }
                }
            } catch {
                log.error("Imported URL could not be decoded.")
            }
        }
        for note in notes {
            if let n = n {
                log.info("Added pages of imported note to currently open note.")
                n.pages += note.pages
            }
            else {
                if SKFileManager.notes.contains(note) {
                    log.info("Note is already in your library, updating its data.")
                    SKFileManager.save(file: note)
                }
                else {
                    log.info("Importing new note.")
                    _ = SKFileManager.add(note: note)
                }
            }
            
        }
        return (notes, images)
    }
}

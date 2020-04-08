//
//  ImportHelper.swift
//  Sketchnoting
//
//  Created by Aryobarzan on 08/04/2020.
//  Copyright © 2020 Aryobarzan. All rights reserved.
//

import UIKit

class ImportHelper {
    static func importItems(urls: [URL], n: NoteX?) -> Bool {
        var notes = [NoteX]()
        var pagesFromImages = [NoteXPage]()
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
                        let page = NoteXPage()
                        page.setBackdrop(image: decodedImage)
                        pagesFromImages.append(page)
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
        if pagesFromImages.count > 0 {
            if let n = n {
                log.info("Added imported image(s) as new page to currently open note.")
                n.pages += pagesFromImages
            }
            else {
                log.info("Created new note from imported images.")
                let note = NoteX(name: "Image Import \(Int.random(in: 1..<200))", parent: SKFileManager.currentFolder?.id, documents: nil)
                note.pages = pagesFromImages
                _ = SKFileManager.add(note: note)
            }
        }
        if notes.count > 0 || pagesFromImages.count > 0 {
            return true
        }
        return false
    }
}

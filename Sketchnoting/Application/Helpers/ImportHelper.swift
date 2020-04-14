//
//  ImportHelper.swift
//  Sketchnoting
//
//  Created by Aryobarzan on 08/04/2020.
//  Copyright © 2020 Aryobarzan. All rights reserved.
//

import UIKit
import PDFKit
import MobileCoreServices

class ImportHelper {
    static func importItems(urls: [URL], n: NoteX?) -> ([NoteX], [UIImage], [PDFDocument], [NoteTypedText]) {
        var notes = [NoteX]()
        var images = [UIImage]()
        var pdfs = [PDFDocument]()
        var texts = [NoteTypedText]()
        for url in urls {
            do {
                let data = try Data(contentsOf: url)
                switch url.typeIdentifier {
                case "public.image", "public.jpeg", "public.jpg", "public.png":
                    if let decodedImage = UIImage(data: data) {
                        images.append(decodedImage)
                    }
                    break
                case "com.sketchnote":
                    if let decodedNote = SKFileManager.decodeNoteFromData(data: data) {
                        notes.append(decodedNote)
                    }
                    break
                case "com.adobe.pdf":
                    if let pdfDocument = PDFDocument(url: url) {
                        pdfs.append(pdfDocument)
                    }
                    break
                case String(kUTTypeText), String(kUTTypeJavaClass), String(kUTTypeCSource), String(kUTTypePlainText), String(kUTTypeSourceCode):
                    if let content = try? String(contentsOf: url) {
                        if !content.isEmpty {
                            let noteTypedText = NoteTypedText(text: content, codeLanguage: "Java")
                            let fileExtension = url.pathExtension
                            print(content)
                            if fileExtension.lowercased() == "c" {
                                noteTypedText.codeLanguage = "C"
                            }
                            texts.append(noteTypedText)
                        }
                    }
                    break
                default:
                    log.error("Unrecognized type for URL: \(url.typeIdentifier ?? "No type identifier")")
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
        return (notes, images, pdfs, texts)
    }
}

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

import Highlightr

class ImportHelper {
    static var importUTTypes = ["public.image", "public.jpeg", "public.jpg", "public.png", "com.sketchnote", "com.adobe.pdf", String(kUTTypeText), String(kUTTypeJavaClass), String(kUTTypeCSource), String(kUTTypePlainText), String(kUTTypeSourceCode), "com.sun.java-source"]
    static func importItems(urls: [URL]) -> ([(URL, Note)], [UIImage], [PDFDocument], [NoteTypedText]) {
        var notes = [(URL, Note)]()
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
                    if let decodedNote = NeoLibrary.decodeNoteFromData(data: data) {
                        notes.append((url, decodedNote))
                    }
                    break
                case "com.adobe.pdf":
                    if let pdfDocument = PDFDocument(url: url) {
                        pdfs.append(pdfDocument)
                    }
                    break
                case String(kUTTypeText), String(kUTTypeJavaClass), String(kUTTypeCSource), String(kUTTypePlainText), String(kUTTypeSourceCode), "com.sun.java-source", String(kUTTypePythonScript), String(kUTTypeShellScript):
                    if let content = try? String(contentsOf: url) {
                        if !content.isEmpty {
                            let typedText = createNoteTypedText(text: content, codeLanguage: nil, fileExtension: url.pathExtension)
                            texts.append(typedText)
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
        return (notes, images, pdfs, texts)
    }
    
    private static func createNoteTypedText(text: String, codeLanguage: String?, fileExtension: String?) -> NoteTypedText {
        let noteTypedText = NoteTypedText(text: text, codeLanguage: "Java")
        if let codeLanguage = codeLanguage {
            noteTypedText.codeLanguage = codeLanguage
        }
        else if let fileExtension = fileExtension {
            noteTypedText.codeLanguage = fileExtension.lowercased()
        }
        log.info("Text file language: \(noteTypedText.codeLanguage)")
        return noteTypedText
    }
}

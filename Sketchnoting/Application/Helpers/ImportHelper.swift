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
import UniformTypeIdentifiers

import Highlightr

class ImportHelper {
    static var importUTTypes = [UTType.image, UTType("com.sketchnote")!, UTType.pdf, UTType.text, UTType.cSource, UTType.plainText, UTType.sourceCode, UTType("com.sun.java-source")!, UTType.archive, UTType("com.pkware.zip-archive")!, UTType.zip]
    static var noteEditingUTTypes = [UTType.image, UTType("com.sketchnote")!, UTType.pdf, UTType.text, UTType.cSource, UTType.plainText, UTType.sourceCode, UTType("com.sun.java-source")!]
    
    private static let operationQueue = OperationQueue()
    static func importItems(urls: [URL], completion: (([(URL, Note)], [UIImage], [PDFDocument], [NoteTypedText]) -> Void)?) {
        operationQueue.cancelAllOperations()
        operationQueue.maxConcurrentOperationCount = 1
        var notes = [(URL, Note)]()
        var images = [UIImage]()
        var pdfs = [PDFDocument]()
        var texts = [NoteTypedText]()
        for url in urls {
            operationQueue.addOperation {
            do {
                let data = try Data(contentsOf: url)
                logger.info("Importing item of type: \(url.typeIdentifier!)")
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
                case "com.pkware.zip-archive", "public.zip-archive":
                    let result = NeoLibrary.importZIP(url: url)
                    switch result {
                    case .Success:
                        logger.info("Success: ZIP file imported.")
                        break
                    case .InvalidFile:
                        logger.error("Failure: ZIP file contains invalid file.")
                        break
                    case .InvalidZIP:
                        logger.error("Failure: ZIP file is invalid.")
                        break
                    case .Failure:
                        logger.error("Failure: ZIP import failed for unknown reason.")
                        break
                    }
                default:
                    logger.error("Unrecognized type for URL: \(url.typeIdentifier ?? "No type identifier")")
                }
            } catch {
                logger.error("Imported URL could not be decoded: \(url.absoluteString)")
                logger.error(error)
            }
            }
        }
        operationQueue.addBarrierBlock {
            if let completion = completion {
                completion(notes, images, pdfs, texts)
            }
        }
        //return (notes, images, pdfs, texts)
    }
    
    static func cancelImports() {
        operationQueue.cancelAllOperations()
    }
    
    private static func createNoteTypedText(text: String, codeLanguage: String?, fileExtension: String?) -> NoteTypedText {
        let noteTypedText = NoteTypedText(text: text, codeLanguage: "Java")
        if let codeLanguage = codeLanguage {
            noteTypedText.codeLanguage = codeLanguage
        }
        else if let fileExtension = fileExtension {
            noteTypedText.codeLanguage = fileExtension.lowercased()
        }
        logger.info("Text file language: \(noteTypedText.codeLanguage)")
        return noteTypedText
    }
}

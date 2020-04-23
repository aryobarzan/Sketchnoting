//
//  NoteXPage.swift
//  Sketchnoting
//
//  Created by Aryobarzan on 07/02/2020.
//  Copyright © 2020 Aryobarzan. All rights reserved.
//

import UIKit
import PencilKit
import PDFKit

class NoteXPage: Codable {
    var canvasDrawing: PKDrawing
    var drawingLabels: [String]
    var drawingViewRects: [CGRect]
    var noteTextArray: [NoteText]
    var backdropPDFData: Data?
    var pdfScale: Float? = 1.0
    var images : [NoteImage]
    var typedTexts : [NoteTypedText]
    
    init() {
        self.canvasDrawing = PKDrawing()
        self.drawingLabels = [String]()
        self.drawingViewRects = [CGRect]()
        self.noteTextArray = [NoteText]()
        self.images = [NoteImage]()
        self.typedTexts = [NoteTypedText]()
    }
    
    //MARK: Decode / Encode
    enum CodingKeys: String, CodingKey {
        case canvasDrawing = "canvasDrawing"
        case drawingLabels = "drawingLabels"
        case drawingViewRects = "drawingViewRects"
        case noteTextArray = "noteTextArray"
        case backdropPDFData = "backdropPDFData"
        case pdfScale = "pdfScale"
        case images = "images"
        case typedTexts = "typedTexts"
    }
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(canvasDrawing, forKey: .canvasDrawing)
        try container.encode(drawingLabels, forKey: .drawingLabels)
        try container.encode(drawingViewRects, forKey: .drawingViewRects)
        try container.encode(noteTextArray, forKey: .noteTextArray)
        try container.encode(backdropPDFData, forKey: .backdropPDFData)
        try container.encode(pdfScale, forKey: .pdfScale)
        try container.encode(images, forKey: .images)
        try container.encode(typedTexts, forKey: .typedTexts)
    }
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        canvasDrawing = try container.decode(PKDrawing.self, forKey: .canvasDrawing)
        drawingLabels = try container.decode([String].self, forKey: .drawingLabels)
        drawingViewRects = try container.decode([CGRect].self, forKey: .drawingViewRects)
        noteTextArray = try container.decode([NoteText].self, forKey: .noteTextArray)
        backdropPDFData = try? container.decode(Data.self, forKey: .backdropPDFData)
        pdfScale = try? container.decode(Float.self, forKey: .pdfScale)
        images = try container.decode([NoteImage].self, forKey: .images)
        typedTexts = try container.decode([NoteTypedText].self, forKey: .typedTexts)
    }
    
    // MARK: drawing recognition
    // This function only stores a recognized drawing's label for a note. The drawing itself (i.e. an image) is not stored.
    // Only the label is necessary, as it is used for search results.
    func addDrawing(drawing: String) {
        if !drawingLabels.contains(drawing.lowercased()) {
            drawingLabels.append(drawing.lowercased())
        }
    }
    
    func addDrawingViewRect(rect: CGRect) {
        if !drawingViewRects.contains(rect) {
            drawingViewRects.append(rect)
        }
    }
    
    func removeDrawingViewRect(rect: CGRect) {
        if drawingViewRects.contains(rect) {
            drawingViewRects.removeAll{$0 == rect}
        }
    }
    
    func updateNoteImage(noteImage: NoteImage) {
        for i in 0..<images.count {
            if images[i] == noteImage {
                images[i] = noteImage
                break
            }
        }
    }
    
    func deleteImage(noteImage: NoteImage) {
        for i in 0..<images.count {
            if images[i] == noteImage {
                images.remove(at: i)
                break
            }
        }
    }
    
    func updateNoteTypedText(typedText: NoteTypedText) {
        for i in 0..<typedTexts.count {
            if typedTexts[i] == typedText {
                typedTexts[i] = typedText
                break
            }
        }
    }
    
    func deleteTypedText(typedText: NoteTypedText) {
        for i in 0..<typedTexts.count {
            if typedTexts[i] == typedText {
                typedTexts.remove(at: i)
                break
            }
        }
    }
    
    //MARK: recognized text
    public func getText(raw: Bool = false) -> String {
        var text: String = ""
        if !raw {
            for textData in noteTextArray {
                text = text + " " + textData.spellchecked
            }
        }
        else {
            for textData in noteTextArray {
                text = text + " " + textData.text
            }
        }
        return text
    }
    
    public func clearTextData() {
        self.noteTextArray = [NoteText]()
    }
    
    public func clear() {
        self.drawingLabels = [String]()
        self.drawingViewRects = [CGRect]()
        self.canvasDrawing = PKDrawing()
        self.noteTextArray = [NoteText]()
    }
    
    func createPDF() -> Data? {
        let pdfWidth = UIScreen.main.bounds.width
        let pdfHeight = UIScreen.main.bounds.height
                
        let bounds = CGRect(x: 0, y: 0, width: pdfWidth, height: pdfHeight)
        let mutableData = NSMutableData()
        UIGraphicsBeginPDFContextToData(mutableData, bounds, nil)
        UIGraphicsBeginPDFPage()
                        
        var yOrigin: CGFloat = 0
        while yOrigin < bounds.maxY {
            let imgBounds = CGRect(x: 0, y: yOrigin, width: pdfWidth, height: pdfHeight)
            var image = canvasDrawing.image(from: imgBounds, scale: 2)
            if let pdfDocument = getPDFDocument() {
                if let page = pdfDocument.page(at: 0) {
                    let pdfImage = page.thumbnail(of: bounds.size, for: .mediaBox)
                    image = pdfImage.mergeWith(topImage: image)
                }
            }
            image.draw(in: imgBounds)
            yOrigin += pdfHeight
        }
        UIGraphicsEndPDFContext()
        return mutableData as Data
    }
    
    public func getAsImage(completion: @escaping (UIImage) -> Void) {
        UITraitCollection(userInterfaceStyle: .light).performAsCurrent {
            var image = canvasDrawing.image(from: UIScreen.main.bounds, scale: 1.0)
            let canvasImage = image
            var pdfImage: UIImage?
            if let pdfDocument = getPDFDocument() {
                if let page = pdfDocument.page(at: 0) {
                    pdfImage = page.thumbnail(of: page.bounds(for: .cropBox).size, for: .cropBox)
                }
            }
            DispatchQueue.global(qos: .utility).async {
                if let pdfImage = pdfImage {
                    image = pdfImage.mergeWith2(withImage: canvasImage)
                }
                DispatchQueue.main.async {
                    completion(image)
                }
            }
        }
    }
    
    func getPDFDocument() -> PDFDocument? {
        if let backdropPDFData = backdropPDFData {
            if let pdfDocument = PDFDocument(data: backdropPDFData) {
                return pdfDocument
            }
        }
        return nil
    }
}

//
//  NoteXPage.swift
//  Sketchnoting
//
//  Created by Aryobarzan on 07/02/2020.
//  Copyright © 2020 Aryobarzan. All rights reserved.
//

import UIKit
import PencilKit

class NoteXPage: Codable {
    var canvasDrawing: PKDrawing
    var drawingLabels: [String]
    var drawingViewRects: [CGRect]
    var noteTextArray: [NoteText]
    
    init() {
        self.canvasDrawing = PKDrawing()
        self.drawingLabels = [String]()
        self.drawingViewRects = [CGRect]()
        self.noteTextArray = [NoteText]()
    }
    
    //MARK: Decode / Encode
    enum CodingKeys: String, CodingKey {
        case canvasDrawing = "canvasDrawing"
        case drawingLabels = "drawingLabels"
        case drawingViewRects = "drawingViewRects"
        case noteTextArray = "noteTextArray"
    }
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(canvasDrawing, forKey: .canvasDrawing)
        try container.encode(drawingLabels, forKey: .drawingLabels)
        try container.encode(drawingViewRects, forKey: .drawingViewRects)
        try container.encode(noteTextArray, forKey: .noteTextArray)
        log.info("Note Page encoded.")

    }
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        canvasDrawing = try container.decode(PKDrawing.self, forKey: .canvasDrawing)
        drawingLabels = try container.decode([String].self, forKey: .drawingLabels)
        drawingViewRects = try container.decode([CGRect].self, forKey: .drawingViewRects)
        noteTextArray = try container.decode([NoteText].self, forKey: .noteTextArray)
        log.info("Note page decoded.")
    }
    
    // Mark
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
            let pdfHeight = canvasDrawing.bounds.maxY + 100
                
            let bounds = CGRect(x: 0, y: 0, width: pdfWidth, height: pdfHeight)
            let mutableData = NSMutableData()
            UIGraphicsBeginPDFContextToData(mutableData, bounds, nil)
            UIGraphicsBeginPDFPage()
                        
            var yOrigin: CGFloat = 0
            let imageHeight: CGFloat = 1024
            while yOrigin < bounds.maxY {
                let imgBounds = CGRect(x: 0, y: yOrigin, width: UIScreen.main.bounds.width, height: min(imageHeight, bounds.maxY - yOrigin))
                let img = canvasDrawing.image(from: imgBounds, scale: 2)
                img.draw(in: imgBounds)
                yOrigin += imageHeight
            }
            UIGraphicsEndPDFContext()
            return mutableData as Data
    }
    
    public func getAsImage(completion: @escaping (UIImage) -> Void) {
        UITraitCollection(userInterfaceStyle: .light).performAsCurrent {
            completion(canvasDrawing.image(from: UIScreen.main.bounds, scale: 1.0))
        }
    }
    
}

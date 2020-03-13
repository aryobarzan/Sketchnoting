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
    private var backdropData: Data?
    private var backdropIsPDF: Bool?
    
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
        case backdropData = "backdropData"
        case backdropIsPDF = "backdropIsPDF"
    }
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(canvasDrawing, forKey: .canvasDrawing)
        try container.encode(drawingLabels, forKey: .drawingLabels)
        try container.encode(drawingViewRects, forKey: .drawingViewRects)
        try container.encode(noteTextArray, forKey: .noteTextArray)
        try container.encode(backdropData, forKey: .backdropData)
        try container.encode(backdropIsPDF, forKey: .backdropIsPDF)
        log.info("Note Page encoded.")

    }
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        canvasDrawing = try container.decode(PKDrawing.self, forKey: .canvasDrawing)
        drawingLabels = try container.decode([String].self, forKey: .drawingLabels)
        drawingViewRects = try container.decode([CGRect].self, forKey: .drawingViewRects)
        noteTextArray = try container.decode([NoteText].self, forKey: .noteTextArray)
        backdropData = try? container.decode(Data.self, forKey: .backdropData)
        backdropIsPDF = try? container.decode(Bool.self, forKey: .backdropIsPDF)
        log.info("Note page decoded.")
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
            if let (backdropData, backdropIsPDF) = getBackdrop() {
                if !backdropIsPDF {
                    if let backdropImage = UIImage(data: backdropData) {
                        image = backdropImage.mergeWith(topImage: image)
                    }
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
            var hasBackdrop = false
            var image = canvasDrawing.image(from: UIScreen.main.bounds, scale: 1.0)
            let canvasImage = image
            if let (backdropData, backdropIsPDF) = getBackdrop() {
                if !backdropIsPDF {
                    hasBackdrop = true
                    DispatchQueue.global(qos: .utility).async {
                        if let backdropImage = UIImage(data: backdropData) {
                            image = backdropImage.mergeWith(topImage: canvasImage)
                        }
                        DispatchQueue.main.async {
                            completion(image)
                        }
                    }
                }
            }
            if !hasBackdrop {
                completion(image)
            }
        }
    }
    
    public func setBackdrop(image: UIImage) {
        self.backdropData = image.jpegData(compressionQuality: 1)
        self.backdropIsPDF = false
    }
    
    public func setBackdrop(data: Data) { // PDF page
        self.backdropData = data
        self.backdropIsPDF = true
    }
    
    public func getBackdrop() -> (Data, Bool)? {
        if backdropData != nil {
            return (backdropData!, backdropIsPDF!)
        }
        return nil
    }
}

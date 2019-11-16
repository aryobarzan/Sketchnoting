//
//  NotePage.swift
//  Sketchnoting
//
//  Created by Aryobarzan on 12/11/2019.
//  Copyright © 2019 Aryobarzan. All rights reserved.
//

import UIKit
import PencilKit

class NotePage: NSObject, NSCoding {
    var canvasDrawing: PKDrawing!
    var image: UIImage?
    var drawingLabels: [String]?
    var drawingViewRects: [CGRect]?
    var textDataArray: [TextData]!
    
    override init() {
        self.drawingLabels = [String]()
        self.textDataArray = [TextData]()
        self.canvasDrawing = PKDrawing()
    }
    
    //MARK: Decode / Encode
    enum Keys: String {
        case canvasDrawing = "CanvasDrawing"
        case image = "Image"
        case drawingLabels = "DrawingLabels"
        case drawingViewRects = "DrawingViewRects"
        case textDataArray = "TextDataArray"
    }
    func encode(with coder: NSCoder) {
        coder.encode(canvasDrawing, forKey: Keys.canvasDrawing.rawValue)
        coder.encode(image?.jpegData(compressionQuality: 1), forKey: Keys.image.rawValue)
        coder.encode(drawingLabels, forKey: Keys.drawingLabels.rawValue)
        coder.encode(drawingViewRects, forKey: Keys.drawingViewRects.rawValue)
        coder.encode(textDataArray, forKey: Keys.textDataArray.rawValue)
    }
    
    required init?(coder: NSCoder) {
        canvasDrawing = coder.decodeObject(forKey: Keys.canvasDrawing.rawValue) as? PKDrawing
        if let imageData = coder.decodeObject(forKey: Keys.image.rawValue) as? Data {
            image = UIImage(data: imageData)
        }
        drawingLabels = coder.decodeObject(forKey: Keys.drawingLabels.rawValue) as? [String]
        drawingViewRects = coder.decodeObject(forKey: Keys.drawingViewRects.rawValue) as? [CGRect]
        textDataArray = coder.decodeObject(forKey: Keys.textDataArray.rawValue) as? [TextData]
    }
    
    // Mark
    // This function only stores a recognized drawing's label for a note. The drawing itself (i.e. an image) is not stored.
    // Only the label is necessary, as it is used for search results.
    func addDrawing(drawing: String) {
        var exists = false
        if drawingLabels == nil {
            drawingLabels = [String]()
        }
        for d in drawingLabels! {
            if d == drawing.lowercased() {
                exists = true
                break
            }
        }
        if !exists {
            drawingLabels!.append(drawing.lowercased())
        }
    }
    
    func addDrawingViewRect(rect: CGRect) {
        var exists = false
        if drawingViewRects == nil {
            drawingViewRects = [CGRect]()
        }
        for r in drawingViewRects! {
            if r == rect {
                exists = true
                break
            }
        }
        if !exists {
            drawingViewRects!.append(rect)
        }
    }
    
    func removeDrawingViewRect(rect: CGRect) {
        if drawingViewRects != nil {
            if drawingViewRects!.contains(rect) {
                drawingViewRects!.removeAll{$0 == rect}
            }
        }
    }
    
    //MARK: recognized text
    public func getText(raw: Bool = false) -> String {
        var text: String = ""
        if textDataArray != nil {
            if !raw {
                for textData in textDataArray {
                    text = text + " " + textData.spellchecked
                }
            }
            else {
                for textData in textDataArray {
                    text = text + " " + textData.original
                }
            }
        }
        return text
    }
    
    public func clearTextData() {
        self.textDataArray = [TextData]()
    }
    
    public func clear() {
        self.drawingLabels = [String]()
        self.drawingViewRects = [CGRect]()
        self.canvasDrawing = PKDrawing()
        self.textDataArray = [TextData]()
        self.image = nil
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
    
}

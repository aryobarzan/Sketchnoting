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

class NotePage: Codable {
    var canvasDrawing: PKDrawing
    private var drawings: [NoteDrawing]
    private var recognizedText: SKRecognizedText
    private var backdropPDFData: Data?
    var pdfScale: Float = 1.0
    private var pdfParsedText: String?
    private var layers: [NoteLayer]
    
    private enum LayerTypeKey : String, CodingKey {
        case type = "type"
    }
    
    init() {
        self.canvasDrawing = PKDrawing()
        self.drawings = [NoteDrawing]()
        self.layers = [NoteLayer]()
        self.recognizedText = SKRecognizedText()
    }
    
    //MARK: Decode / Encode
    enum CodingKeys: String, CodingKey {
        case canvasDrawing = "canvasDrawing"
        case drawings = "noteDrawings"
        case recognizedText = "recognizedText"
        case backdropPDFData = "backdropPDFData"
        case pdfScale = "pdfScale"
        case pdfParsedText = "pdfParsedText"
        case layers = "layers"
    }
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        do {
            try container.encode(layers, forKey: .layers)
        } catch {
            logger.error("Error while encoding layers of note page.")
        }
        try container.encode(canvasDrawing, forKey: .canvasDrawing)
        try container.encode(drawings, forKey: .drawings)
        try container.encode(recognizedText, forKey: .recognizedText)
        try container.encode(backdropPDFData, forKey: .backdropPDFData)
        try container.encode(pdfScale, forKey: .pdfScale)
        try? container.encode(pdfParsedText, forKey: .pdfParsedText)
    }
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        var layersArrayForType = try container.nestedUnkeyedContainer(forKey: .layers)
        var layers = [NoteLayer]()
        var layersArray = layersArrayForType
        do {
            while(!layersArrayForType.isAtEnd) {
                let layer = try layersArrayForType.nestedContainer(keyedBy: LayerTypeKey.self)
                let t = try layer.decode(NoteLayerType.self, forKey: LayerTypeKey.type)
                switch t {
                case .Image:
                    layers.append(try layersArray.decode(NoteImage.self))
                    break
                case .TypedText:
                    layers.append(try layersArray.decode(NoteTypedText.self))
                    break
                }
            }
        } catch {
            logger.error("Decoding a note page's layers failed.")
            logger.error(error)
        }
        self.layers = layers

        canvasDrawing = try container.decode(PKDrawing.self, forKey: .canvasDrawing)
        drawings = (try? container.decode([NoteDrawing].self, forKey: .drawings)) ?? [NoteDrawing]()
        recognizedText = (try? container.decode(SKRecognizedText.self, forKey: .recognizedText)) ?? SKRecognizedText()
        backdropPDFData = try? container.decode(Data.self, forKey: .backdropPDFData)
        pdfScale = try container.decode(Float.self, forKey: .pdfScale)
        pdfParsedText = try? container.decode(String.self, forKey: .pdfParsedText)
    }
    
    func clearCanvas() {
        self.canvasDrawing = PKDrawing()
    }
    
    // MARK: drawing recognition
    // This function only stores a recognized drawing's label for a note. The drawing itself (i.e. an image) is not stored.
    // Only the label is necessary, as it is used for search results.
    
    func addDrawing(label: String, region: CGRect) {
        let drawing = NoteDrawing(label: label, region: region)
        self.addDrawing(drawing: drawing)
    }
    func addDrawing(drawing: NoteDrawing) {
        if !self.hasDrawing(drawing: drawing) {
            self.drawings.append(drawing)
        }
    }
    
    func removeDrawing(drawing: NoteDrawing) {
        if self.hasDrawing(drawing: drawing) {
            drawings.removeAll{$0 == drawing}
        }
    }
    func removeDrawing(region: CGRect) {
        for d in self.drawings {
            if d.getRegion() == region {
                drawings.removeAll{$0 == d}
                break
            }
        }
    }
    
    func hasDrawing(drawing: NoteDrawing) -> Bool {
        for d in self.drawings {
            if d == drawing {
                return true
            }
        }
        return false
    }
    
    func getDrawingLabels() -> [String] {
        var labels = [String]()
        for d in self.drawings {
            if !labels.contains(d.getLabel()) {
                labels.append(d.getLabel())
            }
        }
        return labels
    }
    
    func getDrawings() -> [NoteDrawing] {
        return self.drawings
    }
    
    // MARK: Layers
    func add(layer: NoteLayer) {
        self.layers.append(layer)
    }
    
    func getLayers(type: NoteLayerType? = nil) -> [NoteLayer] {
        if let type = type {
            return layers.filter { $0.type == type }
        }
        return layers
    }
    
    func deleteLayer(layer: NoteLayer) {
        for i in 0..<layers.count {
            if layers[i] == layer {
                layers.remove(at: i)
                break
            }
        }
    }
    
    func deleteLayer(at indexPath: IndexPath) {
        layers.remove(at: indexPath.row)
    }
    
    func insertLayer(_ layer: NoteLayer, at indexPath: IndexPath) {
        layers.insert(layer, at: indexPath.row)
    }
    
    func updateLayer(layer: NoteLayer) {
        for i in 0..<layers.count {
            if layers[i] == layer {
                layers[i] = layer
                break
            }
        }
    }
    
    //MARK: recognized text
    
    public func addRecognizedLine(line: SKRecognizedLine, lineNumber: Int) {
        if recognizedText.lines.isEmpty {
            recognizedText.lines.append(line)
        }
        else {
            recognizedText.lines.insert(line, at: lineNumber)
        }
    }
    
    public func clearRecognizedText() {
        self.recognizedText = SKRecognizedText()
    }
    
    public func getRecognizedText() -> SKRecognizedText {
        return self.recognizedText
    }
    
    // MARK: Helper functions
    
    public func getText(option: NoteTextViewOption = .FullText, parse: Bool = false) -> String {
        var text: String = ""
        switch option {
        case .FullText:
            text += getRecognizedText().getText()
            if !text.isEmpty {
                text += "\n"
            }
            text += getPDFText()
        case .HandwrittenText:
            text += getRecognizedText().getText()
        case .PDFText:
            if parse {
                if let pdfParsedText = pdfParsedText {
                    text += pdfParsedText
                }
                else {
                    updateParsedPDFText()
                    text += pdfParsedText!
                }
            }
            else {
                text += getPDFText()
            }
        }
        return text
    }
    
    private func updateParsedPDFText() {
        pdfParsedText = TextParser.shared.clean(text: getPDFText())
    }
    
    private func getPDFText() -> String {
        if let pdfDocument = getPDFDocument(), let page = pdfDocument.page(at: 0), let pdfText = page.string {
            return pdfText
        }
        return ""
    }
    
    public func clear() {
        self.drawings = [NoteDrawing]()
        self.canvasDrawing = PKDrawing()
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
                    image = pdfImage.mergeAlternatively(with: canvasImage)
                }
                for layer in self.getLayers(type: .Image) {
                    if let noteImage = layer as? NoteImage {
                        image = image.add(image: noteImage)
                    }
                }
                for layer in self.getLayers(type: .TypedText) {
                    if let noteTypedText = layer as? NoteTypedText {
                        image = image.addText(drawText: noteTypedText)
                    }
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
    
    func set(pdfDocument: Data?) {
        self.backdropPDFData = pdfDocument
        updateParsedPDFText()
    }
    
    func getPDFData() -> Data? {
        return backdropPDFData
    }
}

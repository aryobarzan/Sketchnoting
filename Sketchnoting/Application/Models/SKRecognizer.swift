//
//  SKRecognizer.swift
//  Sketchnoting
//
//  Created by Aryobarzan on 26/09/2020.
//  Copyright © 2020 Aryobarzan. All rights reserved.
//

import UIKit
import PencilKit

import MLKitDigitalInkRecognition

enum RecognitionType {
    case Text
    case Drawing
}

class SKRecognizer {
    private static var notificationInitialized = false
    private static var textRecognizer: DigitalInkRecognizer!
    private static var drawingRecognizer: DigitalInkRecognizer!
    public static func recognize(canvasView: PKCanvasView, recognitionType: RecognitionType = .Text, handleFinish:@escaping ((_ success: Bool, _ param: String?)->())) {
        if !isInitialized() {
            initializeRecognizers()
            log.error("Cannot recognize ink yet: recognizers are not initialized.")
        }
        else {
            switch recognitionType {
            case .Text:
                var strokes: [Stroke] = [Stroke]()
                var points: [StrokePoint] = [StrokePoint]()
                var inks: [Ink] = [Ink]()
                // let width: Float = Float(canvasView.bounds.size.width)
                // let height: Float = 20.0
                var previousStroke: PKStroke?
                for stroke in canvasView.drawing.strokes {
                    if previousStroke == nil {
                        previousStroke = stroke
                    }
                    if abs(stroke.renderBounds.minY - previousStroke!.renderBounds.minY) < 40 {
                        for point in stroke.path.interpolatedPoints(by: .parametricStep(1.0)) {
                            points.append(StrokePoint.init(x: Float(point.location.x), y: Float(point.location.y), t: Int(point.timeOffset * 1000)))
                        }
                        strokes.append(Stroke.init(points: points))
                        points = []
                        previousStroke = stroke
                    }
                    else {
                        if strokes.count > 0 {
                            inks.append(Ink.init(strokes: strokes))
                        }
                        previousStroke = stroke
                        strokes = [Stroke]()
                        for point in stroke.path.interpolatedPoints(by: .parametricStep(1.0)) {
                            points.append(StrokePoint.init(x: Float(point.location.x), y: Float(point.location.y), t: Int(point.timeOffset * 1000)))
                        }
                        strokes.append(Stroke.init(points: points))
                        points = []
                    }
                }
                if !strokes.isEmpty {
                    inks.append(Ink.init(strokes: strokes))
                }
                for ink in inks {
                    textRecognizer.recognize(
                        ink: ink,
                        //context: context,
                        completion: {
                            (result: DigitalInkRecognitionResult?, error: Error?) in
                            if let result = result, let candidate = result.candidates.first {
                                log.info("Recognized: \(candidate.text)")
                                handleFinish(true, candidate.text)
                            } else {
                                log.error(error.debugDescription)
                                handleFinish(false, nil)
                            }
                        })
                }
                break
            case .Drawing:
                var strokes: [Stroke] = [Stroke]()
                var points: [StrokePoint] = [StrokePoint]()
                for stroke in canvasView.drawing.strokes {
                    for point in stroke.path.interpolatedPoints(by: .parametricStep(1.0)) {
                        points.append(StrokePoint.init(x: Float(point.location.x), y: Float(point.location.y), t: Int(point.timeOffset * 1000)))
                    }
                    strokes.append(Stroke.init(points: points))
                    points = []
                }
                if !strokes.isEmpty {
                    let ink = Ink.init(strokes: strokes)
                    let drawingArea = WritingArea.init(width: Float(canvasView.bounds.size.width), height: Float(canvasView.bounds.size.height))
                    let context = DigitalInkRecognitionContext.init(preContext: "", writingArea: drawingArea)
                    drawingRecognizer.recognize(
                        ink: ink,
                        context: context,
                        completion: {
                            (result: DigitalInkRecognitionResult?, error: Error?) in
                            if let result = result, let candidate = result.candidates.first {
                                log.info("Recognized Drawing: \(candidate.text)")
                                handleFinish(true, candidate.text)
                            } else {
                                log.error(error.debugDescription)
                                handleFinish(false, nil)
                            }
                        })
                }
                break
            }
        }
    }
    
    public static func recognizeText(pkStrokes: [PKStroke], handleFinish:@escaping ((_ success: Bool, _ param: SKRecognizedLine?, _ lineNumber: Int)->())) {
        var strokesByLine = [[PKStroke]]()
        for stroke in pkStrokes {
            var groupIndex: Int?
            var groupMean: CGFloat?
            for i in 0..<strokesByLine.count {
                var groupMeanY: CGFloat = 0.0;
                var groupMinY: CGFloat = 9999.0;
                var groupMaxY: CGFloat = 0.0;
                for s in strokesByLine[i] {
                    groupMeanY += s.renderBounds.minY
                    groupMinY = min(groupMinY, s.renderBounds.minY)
                    groupMaxY = max(groupMaxY, s.renderBounds.maxY)
                }
                groupMeanY = groupMeanY / CGFloat(strokesByLine[i].count)
                if groupMean == nil {
                    if stroke.renderBounds.midY >= groupMinY && stroke.renderBounds.midY <= groupMaxY {
                        groupMean = groupMeanY
                        groupIndex = i
                    }
                }
                else {
                    if abs(stroke.renderBounds.minY - groupMeanY) < abs(stroke.renderBounds.minY - groupMean!) {
                        groupMean = groupMeanY
                        groupIndex = i
                    }
                }
            }
            if groupIndex == nil {
                var newGroup = [PKStroke]()
                newGroup.append(stroke)
                strokesByLine.append(newGroup)
            }
            else {
                var updatedGroup = strokesByLine[groupIndex!]
                updatedGroup.append(stroke)
                strokesByLine[groupIndex!] = updatedGroup
            }
        }
        log.info("Detected \(strokesByLine.count) line(s).")
        var inks = [([PKStroke], Ink)]()
        for line in strokesByLine {
            if let ink = self.createInkFrom(pkStrokes: line) {
                inks.append((line, ink))
            }
        }
        var recognitions = [Int : String]()
        for i in 0..<inks.count {
            textRecognizer.recognize(
                ink: inks[i].1,
                completion: {
                    (result: DigitalInkRecognitionResult?, error: Error?) in
                    if let result = result, let candidate = result.candidates.first {
                        if !candidate.text.isEmpty {
                            var recognizedWords = [SKRecognizedWord]()
                            let words = candidate.text.components(separatedBy: " ")
                            
                            var iterations = 5
                            var strokesByWord = [[PKStroke]]()
                            var modifier: CGFloat = 0
                            // to update: retain bestResult during iterations
                            repeat {
                                strokesByWord = [[PKStroke]]()
                                var currentWordStrokes = [PKStroke]()
                                var previousStroke: PKStroke?
                                for j in 0..<inks[i].0.count {
                                    let stroke = inks[i].0[j]
                                    if previousStroke != nil {
                                        if stroke.renderBounds.intersects(previousStroke!.renderBounds) || (stroke.renderBounds.minX - previousStroke!.renderBounds.maxX) <= (10 + modifier) {
                                            currentWordStrokes.append(stroke)
                                        }
                                        else {
                                            if !currentWordStrokes.isEmpty {
                                                strokesByWord.append(currentWordStrokes)
                                                currentWordStrokes = [PKStroke]()
                                                currentWordStrokes.append(stroke)
                                            }
                                        }
                                        previousStroke = stroke
                                    }
                                    else {
                                        currentWordStrokes.append(stroke)
                                        previousStroke = stroke
                                    }
                                }
                                if !currentWordStrokes.isEmpty {
                                    strokesByWord.append(currentWordStrokes)
                                }
                                log.info("Number of words segmented: \(strokesByWord.count)")
                                iterations -= 1
                                if strokesByWord.count > words.count {
                                    modifier -= 2
                                }
                                else if strokesByWord.count < words.count {
                                    modifier += 2
                                }
                            } while (strokesByWord.count != words.count && iterations > 0)
                            
                            for j in 0..<words.count {
                                var renderBounds: CGRect?
                                if (j < strokesByWord.count && strokesByWord[j].count > 0) {
                                    renderBounds = CGRect(x: strokesByWord[j].first!.renderBounds.minX, y: strokesByWord[j].first!.renderBounds.minY, width: strokesByWord[j].last!.renderBounds.maxX, height: strokesByWord[j].last!.renderBounds.maxY)
                                }
                                recognizedWords.append(SKRecognizedWord(text: words[j], renderBounds: renderBounds))
                            }
                            let recognizedLine = SKRecognizedLine(text: result.candidates.first!.text, words: recognizedWords)
                            log.info("Recognized: \(candidate.text)")
                            recognitions[i] = candidate.text
                            handleFinish(true, recognizedLine, i)
                        }
                        else {
                            handleFinish(false, nil, -1)
                        }
                    } else {
                        log.error(error.debugDescription)
                        handleFinish(false, nil, -1)
                    }
                })
        }
    }
    
    private static func createInkFrom(pkStrokes: [PKStroke]) -> Ink? {
        var strokes: [Stroke] = [Stroke]()
        var points: [StrokePoint] = [StrokePoint]()
        for s in pkStrokes {
            for point in s.path.interpolatedPoints(by: .parametricStep(1.0)) {
                points.append(StrokePoint.init(x: Float(point.location.x), y: Float(point.location.y), t: Int(point.timeOffset * 1000)))
            }
            strokes.append(Stroke.init(points: points))
            points = []
        }
        if !strokes.isEmpty {
            return Ink.init(strokes: strokes)
        }
        return nil
    }
    
    private static func downloadModels() {
        for identifier in [DigitalInkRecognitionModelIdentifier.en, DigitalInkRecognitionModelIdentifier.autodraw] {
            let model = DigitalInkRecognitionModel.init(modelIdentifier: identifier)
            let modelManager = MLKitCommon.ModelManager.modelManager()
            if !modelManager.isModelDownloaded(model) {
                log.info("Downloading Model: \(identifier.languageTag)")
                modelManager.download(
                  model,
                  conditions: ModelDownloadConditions.init(
                    allowsCellularAccess: true, allowsBackgroundDownloading: true)
                )
            }
        }
    }
    
    public static func initializeRecognizers() {
        if !notificationInitialized {
            log.info("Initialized notification for model downloads.")
            NotificationCenter.default.addObserver(
              forName: NSNotification.Name.mlkitModelDownloadDidSucceed,
              object: nil,
              queue: OperationQueue.main,
              using: {
                (notification) in
                log.info("Model download succeeded")
                initializeRecognizers()
              })
            notificationInitialized = true
        }
        
        if textRecognizer == nil {
            let model = DigitalInkRecognitionModel.init(modelIdentifier: DigitalInkRecognitionModelIdentifier.en)
            let modelManager = MLKitCommon.ModelManager.modelManager()
            if modelManager.isModelDownloaded(model) {
                let options: DigitalInkRecognizerOptions = DigitalInkRecognizerOptions.init(model: model)
                textRecognizer = DigitalInkRecognizer.digitalInkRecognizer(options: options)
                log.info("Text Recognizer: initialized")
            }
            else {
                downloadModels()
            }
        }
        
        if drawingRecognizer == nil {
            let autodrawTag = DigitalInkRecognitionModelIdentifier.autodraw
            let model = DigitalInkRecognitionModel.init(modelIdentifier: autodrawTag)
            let modelManager = MLKitCommon.ModelManager.modelManager()
            if modelManager.isModelDownloaded(model) {
                let options: DigitalInkRecognizerOptions = DigitalInkRecognizerOptions.init(model: model)
                drawingRecognizer = DigitalInkRecognizer.digitalInkRecognizer(options: options)
                log.info("Drawing Recognizer: initialized")
            }
            else {
                downloadModels()
            }
        }
    }
    
    private static func isInitialized() -> Bool {
        return textRecognizer != nil && drawingRecognizer != nil
    }
}

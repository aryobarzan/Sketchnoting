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
                // let preContext = ""
                // let writingArea = WritingArea.init(width: width, height: height)
                // let context = DigitalInkRecognitionContext.init(preContext: preContext, writingArea: writingArea)
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

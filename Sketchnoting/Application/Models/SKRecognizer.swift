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
            logger.error("Cannot recognize ink yet: recognizers are not initialized.")
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
                                logger.info("Recognized: \(candidate.text)")
                                handleFinish(true, candidate.text)
                            } else {
                                logger.error(error.debugDescription)
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
                                logger.info("Recognized Drawing: \(candidate.text)")
                                handleFinish(true, candidate.text)
                            } else {
                                logger.error(error.debugDescription)
                                handleFinish(false, nil)
                            }
                        })
                }
                break
            }
        }
    }
    
    public static func recognizeText(pkStrokes: [PKStroke], handleFinish:@escaping ((_ success: Bool, _ param: SKRecognizedLine?, _ lineNumber: Int)->())) {
        if !isInitialized() {
            initializeRecognizers()
            logger.error("Cannot recognize ink yet: recognizers are not initialized.")
            return
        }
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
        logger.info("Detected \(strokesByLine.count) line(s).")
        var inks = [([PKStroke], Ink)]()
        for line in strokesByLine {
            if let ink = self.createInkFrom(pkStrokes: line) {
                inks.append((line, ink))
            }
        }
        for i in 0..<inks.count {
            textRecognizer.recognize(
                ink: inks[i].1,
                completion: {
                    (result: DigitalInkRecognitionResult?, error: Error?) in
                    if let result = result, let candidate = result.candidates.first {
                        if !candidate.text.isEmpty {
                            var recognizedWords = [SKRecognizedWord]()
                            let words = candidate.text.components(separatedBy: " ")
//                            let centersTest = kmeans(centersCount: words.count, strokes: inks[i].0)
//                            print("Found these centers:")
//                            for strokeArray in centersTest {
//                                print("Word:")
//                                for sTemp in strokeArray {
//                                    print("Stroke - \(sTemp.renderBounds)")
//                                }
//                            }
                            
                            var iterations = 0
                            var strokesByWord = [[PKStroke]]()
                            var modifier: CGFloat = 0
                            var bestStrokesByWord = [[PKStroke]]()
                            var bestStrokesByWordCount = -1
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
                                logger.info("(Iteration \(iterations)) Number of words segmented: \(strokesByWord.count)")
                                iterations += 1
                                if bestStrokesByWordCount == -1 {
                                    bestStrokesByWord = strokesByWord
                                    bestStrokesByWordCount = strokesByWord.count
                                }
                                if strokesByWord.count > words.count {
                                    modifier -= 2
                                    if bestStrokesByWordCount > words.count && words.count - strokesByWord.count < words.count - bestStrokesByWordCount {
                                        bestStrokesByWord = strokesByWord
                                        bestStrokesByWordCount = strokesByWord.count
                                    }
                                }
                                else if strokesByWord.count < words.count {
                                    modifier += 2
                                    if bestStrokesByWordCount < words.count && words.count - strokesByWord.count > words.count - bestStrokesByWordCount {
                                        bestStrokesByWord = strokesByWord
                                        bestStrokesByWordCount = strokesByWord.count
                                    }
                                }
                                else {
                                    bestStrokesByWord = strokesByWord
                                    break
                                }
                            } while (strokesByWord.count != words.count && iterations < 5)
                            strokesByWord = bestStrokesByWord
                            for j in 0..<words.count {
                                var renderBounds: CGRect?
                                if (j < strokesByWord.count && strokesByWord[j].count > 0) {
                                    if strokesByWord[j].first != nil && strokesByWord[j].last != nil {
                                        var wordHeight = strokesByWord[j].last!.renderBounds.height
                                        for stroke in strokesByWord[j] {
                                            if stroke.renderBounds.height > wordHeight {
                                                wordHeight = stroke.renderBounds.height
                                            }
                                        }
                                        renderBounds = CGRect(x: strokesByWord[j].first!.renderBounds.minX, y: strokesByWord[j].first!.renderBounds.minY, width: strokesByWord[j].last!.renderBounds.maxX - strokesByWord[j].first!.renderBounds.minX, height: wordHeight)
                                    }
                                }
                                recognizedWords.append(SKRecognizedWord(text: words[j], renderBounds: renderBounds))
                            }
                            var lineHeight = inks[i].0.last!.renderBounds.height
                            for stroke in inks[i].0 {
                                if stroke.renderBounds.height > lineHeight {
                                    lineHeight = stroke.renderBounds.height
                                }
                            }
                            if inks[i].0.first != nil && inks[i].0.last != nil {
                                let lineRenderBounds = CGRect(x: inks[i].0.first!.renderBounds.minX, y: inks[i].0.first!.renderBounds.minY, width: inks[i].0.last!.renderBounds.maxX - inks[i].0.first!.renderBounds.minX, height: lineHeight)
                                let recognizedLine = SKRecognizedLine(text: result.candidates.first!.text, words: recognizedWords, renderBounds: lineRenderBounds)
                                logger.info("Recognized: \(candidate.text)")
                                handleFinish(true, recognizedLine, i)
                            }
                            else {
                                logger.error("Unknown error (1) when recognizing line of text.")
                                handleFinish(false, nil, -1)
                            }
                        }
                        else {
                            handleFinish(false, nil, -1)
                        }
                    } else {
                        logger.error(error.debugDescription)
                        handleFinish(false, nil, -1)
                    }
                })
        }
    }
    
    private static func kmeans(centersCount: Int, strokes: [PKStroke]) -> [[PKStroke]] {
        var centers = [CGPoint]()
        let sampledStrokes = strokes.choose(centersCount)
        for s in sampledStrokes {
            centers.append(s.renderBounds.center)
        }
        
        var centerDistanceChange = 0.0
        var iteration = 0
        repeat {
            var newCenters = [CGPoint](repeating: CGPoint(x: 0, y: 0), count: centersCount)
            
            var counts = [Double](repeating: 0, count: centersCount)
            
            for stroke in strokes {
                var indexOfClosestCenter = 0
                var distance: Float = 9999
                for i in 0..<centers.count {
                    if cgpointDistance(from: centers[i], to: stroke.renderBounds.center) < distance {
                        indexOfClosestCenter = i
                        distance = cgpointDistance(from: centers[i], to: stroke.renderBounds.center)
                    }
                }
                let temp = newCenters[indexOfClosestCenter]
                newCenters[indexOfClosestCenter] = CGPoint(x: temp.x + stroke.renderBounds.center.x, y: temp.y + stroke.renderBounds.center.y)
                counts[indexOfClosestCenter] += 1
            }
            
            for i in 0..<centersCount {
                newCenters[i] = CGPoint(x: newCenters[i].x/CGFloat(counts[i]), y: newCenters[i].y/CGFloat(counts[i]))
            }
            
            centerDistanceChange = 0.0
            for i in 0..<centersCount {
                centerDistanceChange += Double(cgpointDistance(from: centers[i], to: newCenters[i]))
            }
            print("Iteration #\(iteration)")
            print("Convergence: \(centerDistanceChange)")
            centers = newCenters
            iteration += 1
        } while centerDistanceChange > 1 && iteration < 50
        
        var segmentedStrokes = [Int : [PKStroke]]()
        for stroke in strokes {
            var indexOfClosestCenter = 0
            var distance: Float = 9999
            for i in 0..<centers.count {
                let temp = cgpointDistance(from: centers[i], to: stroke.renderBounds.center)
                if temp < distance {
                    distance = temp
                    indexOfClosestCenter = i
                }
            }
            if segmentedStrokes[indexOfClosestCenter] == nil {
                segmentedStrokes[indexOfClosestCenter] =  [PKStroke]()
            }
            var temp = segmentedStrokes[indexOfClosestCenter]!
            temp.append(stroke)
            segmentedStrokes[indexOfClosestCenter] = temp.sorted(by: {x_1, x_2 in
                return x_1.renderBounds.minX < x_2.renderBounds.minX
            })
            
        }
        let ordered = segmentedStrokes.values.sorted(by: {word_1, word_2 in
            return word_1[0].renderBounds.minX < word_2[0].renderBounds.minX
        })
        return ordered
    }
    
    private static func cgpointDistanceSquared(from: CGPoint, to: CGPoint) -> Float {
        let x_1 = (from.x - to.x) * (from.x - to.x)
        let y_1 = (from.y - to.y) * (from.y - to.y)
        return Float(y_1 + x_1)
    }
    
    private static func cgpointDistance(from: CGPoint, to: CGPoint) -> Float {
        let result: Float = cgpointDistanceSquared(from: from, to: to)
        return result.squareRoot()
    }
    
    public static func recognizeNoteDrawing(noteDrawing: NoteDrawing, pkStrokes: [PKStroke], handleFinish:@escaping ((_ success: Bool, _ param: NoteDrawing?)->())) {
        if !isInitialized() {
            initializeRecognizers()
            logger.error("Cannot recognize ink yet: recognizers are not initialized.")
            return
        }
        var strokes: [Stroke] = [Stroke]()
        var points: [StrokePoint] = [StrokePoint]()
        for stroke in pkStrokes {
            for point in stroke.path.interpolatedPoints(by: .parametricStep(1.0)) {
                points.append(StrokePoint.init(x: Float(point.location.x), y: Float(point.location.y), t: Int(point.timeOffset * 1000)))
            }
            strokes.append(Stroke.init(points: points))
            points = []
        }
        if !strokes.isEmpty {
            let ink = Ink.init(strokes: strokes)
            let drawingArea = WritingArea.init(width: Float(noteDrawing.getRegion().size.width), height: Float(noteDrawing.getRegion().size.height))
            let context = DigitalInkRecognitionContext.init(preContext: "", writingArea: drawingArea)
            drawingRecognizer.recognize(
                ink: ink,
                context: context,
                completion: {
                    (result: DigitalInkRecognitionResult?, error: Error?) in
                    if let result = result, let candidate = result.candidates.first {
                        logger.info("Recognized Drawing: \(candidate.text)")
                        let updatedNoteDrawing = NoteDrawing(label: candidate.text, region: noteDrawing.getRegion())
                        handleFinish(true, updatedNoteDrawing)
                    } else {
                        logger.error(error.debugDescription)
                        handleFinish(false, nil)
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
                logger.info("Downloading Model: \(identifier.languageTag)")
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
            logger.info("Initialized notification for model downloads.")
            NotificationCenter.default.addObserver(
              forName: NSNotification.Name.mlkitModelDownloadDidSucceed,
              object: nil,
              queue: OperationQueue.main,
              using: {
                (notification) in
                logger.info("Model download succeeded.")
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
                logger.info("Text Recognizer: initialized.")
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
                logger.info("Drawing Recognizer: initialized")
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

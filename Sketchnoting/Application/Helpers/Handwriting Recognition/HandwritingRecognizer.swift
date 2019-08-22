//
//  HandwritingRecognizer.swift
//  Sketchnoting
//
//  Created by Aryobarzan on 23/07/2019.
//  Copyright © 2019 Aryobarzan. All rights reserved.
//

import UIKit
import Firebase

class HandwritingRecognizer {
    private let vision: Vision!
    private let textRecognizer: VisionTextRecognizer!
    private var textRecognizerCloud: VisionTextRecognizer!
    init() {
        self.vision = Vision.vision()
        self.textRecognizer = vision.onDeviceTextRecognizer()
        
        let options = VisionCloudTextRecognizerOptions()
        options.modelType = .dense
        self.textRecognizerCloud = vision.cloudTextRecognizer(options: options)
    }
    
    public func recognize(spellcheck: Bool = true, note: Sketchnote, view: UIView, penTools: [PenTool], canvasFrame: CGRect, handleFinish:@escaping ((_ success: Bool, _ param: TextData?)->())){
        var newPenTools = [PenTool]()
        
        if let textDataArray = note.textDataArray {
            for penTool in penTools {
                var alreadyRecognized = false
                for textData in textDataArray {
                    if textData.paths.contains(penTool.path.boundingBox) {
                        alreadyRecognized = true
                        break
                    }
                }
                if !alreadyRecognized {
                    newPenTools.append(penTool)
                }
            }
        }
        
        let canvas = UIView(frame: canvasFrame)
        canvas.backgroundColor = .black
        var newPathsBoundingBoxes = [CGRect]()
        for penTool in newPenTools {
            newPathsBoundingBoxes.append(penTool.path.boundingBox)
            let newPath = penTool.path.copy(strokingWithWidth: penTool.lineWidth, lineCap: .round, lineJoin: .round, miterLimit: 0)
            let layer = CAShapeLayer()
            layer.path = newPath
            layer.strokeColor = UIColor.white.cgColor
            layer.fillColor = UIColor.white.cgColor
            canvas.layer.addSublayer(layer)
        }
        view.addSubview(canvas)
        let image = canvas.asImage()
        let visionImage = VisionImage(image: image)
        
        switch SettingsManager.textRecognitionSetting() {
        case .OnDevice:
            textRecognizer.process(visionImage) { result, error in
                guard error == nil, let result = result else {
                    canvas.removeFromSuperview()
                    handleFinish(false, nil)
                    return
                }
                let textData = TextData(visionText: result, original: result.text, paths: newPathsBoundingBoxes, imageSize: canvas.frame.size, spellcheck: spellcheck)
                canvas.removeFromSuperview()
                handleFinish(true, textData)
            }
        case .CloudSparse:
            self.textRecognizerCloud = vision.cloudTextRecognizer()
            textRecognizerCloud.process(visionImage) { result, error in
                guard error == nil, let result = result else {
                    canvas.removeFromSuperview()
                    print(error)
                    handleFinish(false, nil)
                    return
                }
                let textData = TextData(visionText: result, original: result.text, paths: newPathsBoundingBoxes, imageSize: canvas.frame.size, spellcheck: spellcheck)
                canvas.removeFromSuperview()
                handleFinish(true, textData)
            }
        case .CloudDense:
            let options = VisionCloudTextRecognizerOptions()
            options.modelType = .dense
            self.textRecognizerCloud = vision.cloudTextRecognizer(options: options)
            textRecognizerCloud.process(visionImage) { result, error in
                guard error == nil, let result = result else {
                    canvas.removeFromSuperview()
                    print(error)
                    handleFinish(false, nil)
                    return
                }
                let textData = TextData(visionText: result, original: result.text, paths: newPathsBoundingBoxes, imageSize: canvas.frame.size, spellcheck: spellcheck)
                canvas.removeFromSuperview()
                handleFinish(true, textData)
            }
        }
    }
}

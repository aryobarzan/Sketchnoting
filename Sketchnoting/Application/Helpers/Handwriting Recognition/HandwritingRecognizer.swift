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
    
    public func recognize(spellcheck: Bool = true, image: UIImage, handleFinish:@escaping ((_ success: Bool, _ param: TextData?)->())){
        let visionImage = VisionImage(image: image)
        
        switch SettingsManager.textRecognitionSetting() {
        case .OnDevice:
            textRecognizer.process(visionImage) { result, error in
                guard error == nil, let result = result else {
                    handleFinish(false, nil)
                    return
                }
                let textData = TextData(visionText: result, original: result.text, spellcheck: spellcheck)
                handleFinish(true, textData)
            }
        case .CloudSparse:
            self.textRecognizerCloud = vision.cloudTextRecognizer()
            textRecognizerCloud.process(visionImage) { result, error in
                guard error == nil, let result = result else {
                    log.error(error.debugDescription)
                    handleFinish(false, nil)
                    return
                }
                let textData = TextData(visionText: result, original: result.text, spellcheck: spellcheck)
                handleFinish(true, textData)
            }
        case .CloudDense:
            let options = VisionCloudTextRecognizerOptions()
            options.modelType = .dense
            self.textRecognizerCloud = vision.cloudTextRecognizer(options: options)
            textRecognizerCloud.process(visionImage) { result, error in
                guard error == nil, let result = result else {
                    log.error(error.debugDescription)
                    handleFinish(false, nil)
                    return
                }
                let textData = TextData(visionText: result, original: result.text, spellcheck: spellcheck)
                handleFinish(true, textData)
            }
        }
    }
}

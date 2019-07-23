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
    
    init() {
        self.vision = Vision.vision()
        self.textRecognizer = vision.onDeviceTextRecognizer()
    }
    
    public func recognize(image: UIImage, postprocess: Bool) -> (VisionText?, String?) {
        if let visionText = recognizeText(image: image) {
            let postprocessed = OCRHelper.postprocess(text: visionText.text)
            return (visionText, postprocessed)
        }
        return (nil, nil)
    }
    
    private func recognizeText(image: UIImage) -> VisionText? {
        var visionText: VisionText?
        let visionImage = VisionImage(image: image)
        let dispatchGroup = DispatchGroup()
        dispatchGroup.enter()
        textRecognizer.process(visionImage) { result, error in
            
            guard error == nil, let result = result else {
                dispatchGroup.leave()
                return
            }
            visionText = result
            let resultText = OCRHelper.postprocess(text: result.text)
            print(resultText)
            
            dispatchGroup.leave()
        }
        dispatchGroup.wait()
        return visionText
    }
}

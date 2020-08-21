//
//  HandwritingRecognizer.swift
//  Sketchnoting
//
//  Created by Aryobarzan on 23/07/2019.
//  Copyright © 2019 Aryobarzan. All rights reserved.
//

import UIKit
import Firebase
import Alamofire
import SwiftyJSON
import MLKit

class HandwritingRecognizer {
    private let vision: Vision!
    private let textRecognizer: TextRecognizer!
    private var textRecognizerCloud: VisionTextRecognizer!
    init() {
        self.vision = Vision.vision()
        self.textRecognizer = TextRecognizer.textRecognizer()
        
        let options = VisionCloudTextRecognizerOptions()
        options.modelType = .dense
        self.textRecognizerCloud = vision.cloudTextRecognizer(options: options)
    }
    
    public func recognize(spellcheck: Bool = true, image: UIImage, handleFinish:@escaping ((_ success: Bool, _ param: NoteText?)->())){
        let visionImage = MLKit.VisionImage(image: image)
        let visionImageCloud = Firebase.VisionImage(image: image)
        var offline = false
        
        switch SettingsManager.textRecognitionSetting() {
        case .OnDevice:
            offline = true
            break
        case .CloudSparse:
            self.textRecognizerCloud = vision.cloudTextRecognizer()
            textRecognizerCloud.process(visionImageCloud) { result, error in
                guard error == nil, let result = result else {
                    log.error(error.debugDescription)
                    handleFinish(false, nil)
                    return
                }
                let noteText = NoteText(visionText: result, spellcheck: spellcheck)
                handleFinish(true, noteText)
            }
            break
        case .CloudDense:
            FirebaseUsage.shared.getAPIUsage(completion: {remaining in
                log.info("Remaining usages for Firebase Dense: \(remaining)")
                if remaining > 0 {
                    FirebaseUsage.shared.sendAPIUsage()
                    let options = VisionCloudTextRecognizerOptions()
                    options.modelType = .dense
                    self.textRecognizerCloud = self.vision.cloudTextRecognizer(options: options)
                    self.textRecognizerCloud.process(visionImageCloud) { result, error in
                        guard error == nil, let result = result else {
                            log.error(error.debugDescription)
                            handleFinish(false, nil)
                            return
                        }
                        let noteText = NoteText(visionText: result, spellcheck: spellcheck)
                        handleFinish(true, noteText)
                    }
                }
                else {
                    offline = true
                }
            })
            break
        }
        if offline {
            textRecognizer.process(visionImage) { result, error in
                guard error == nil, let result = result else {
                    handleFinish(false, nil)
                    return
                }
                let noteText = NoteText(visionText: result, spellcheck: spellcheck)
                handleFinish(true, noteText)
            }
        }
    }
}

class FirebaseUsage {
    static var shared = FirebaseUsage()
    func getAPIUsage(completion: @escaping (Int) -> Void) {
        let headers: HTTPHeaders = [
            "Accept": "application/json"
        ]
        AF.request("https://solemio.uni.lu/sketchnoting/limits", method: .get , encoding: JSONEncoding.default, headers: headers).responseJSON { response in
            let responseResult = response.result
            var json = JSON()
            switch responseResult {
            case .success(let res):
                json = JSON(res)
            case .failure(let error):
                log.error(error.localizedDescription)
                completion(0)
                return
            }
            if let remaining = json["firebase-dense"].int {
                completion(remaining)
            }
            else {
                completion(0)
            }
        }
    }
    
    func sendAPIUsage() {
        let parameters: Parameters = ["device_name": UIDevice.current.name, "service": "firebase-dense"]
        let headers: HTTPHeaders = [
            "Accept": "application/json"
        ]
        AF.request("https://solemio.uni.lu/sketchnoting/registerRequest", method: .post, parameters: parameters, encoding: JSONEncoding.default, headers: headers)
        .responseJSON { response in
            let responseResult = response.result
            var json = JSON()
            switch responseResult {
            case .success(let res):
                json = JSON(res)
                log.info(json)
            case .failure(let error):
                log.error(error.localizedDescription)
                return
            }
        }
    }
}

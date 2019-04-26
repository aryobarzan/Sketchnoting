//
//  OCRHelper.swift
//  Sketchnoting
//
//  Created by Aryobarzan on 15/03/2019.
//  Copyright © 2019 Aryobarzan. All rights reserved.
//

import Foundation
import GPUImage

class OCRHelper {
    
    // Text checker
    private static var textChecker = UITextChecker()
    
    static func postprocess(text: String) -> String {
        let firstRun = spellcheckManually(original: text)
        print("First run: " + firstRun)
        let secondRun = spellcheckAutomatically(original: firstRun)
        print("Second run: " + secondRun)
        return secondRun
    }
    
    private static func spellcheckManually(original: String) -> String {
        var text = original.replacingOccurrences(of: "\n", with: " ")
        var words = text.components(separatedBy: " ")
        var index = 0
        for word in words {
            if word.count >= 2 && containsLetter(input: word) && containsSpecialSymbolOrNumber(input: word) {
                let misspelledRange =
                    textChecker.rangeOfMisspelledWord(in: text,
                                                      range: NSRange(text.index(of: word)!.encodedOffset..<text.endIndex(of: word)!.encodedOffset),
                                                      startingAt: 0,
                                                      wrap: false,
                                                      language: "en_US")
                
                if misspelledRange.location != NSNotFound,
                    let guesses = textChecker.guesses(forWordRange: misspelledRange,
                                                      in: text,
                                                      language: "en_US")
                {
                    if guesses.count > 0 {
                        words[index] = guesses.first!
                        text = words.joined(separator: " ")
                    }
                }
                index = index + 1
            }
            
        }
        return words.joined(separator: " ")
    }
    private static func containsLetter(input: String) -> Bool {
        for chr in input.lowercased() {
            if (chr >= "a" && chr <= "z") {
                return true
            }
        }
        return false
    }
    private static func containsSpecialSymbolOrNumber(input: String) -> Bool {
        var count = 0
        for chr in input.lowercased() {
            if (chr >= "a" && chr <= "z"){
                count += 1
            }
        }
        if count == input.count {
            return false
        }
        return true
    }
    private static func spellcheckAutomatically(original: String) -> String {
        var text = original.replacingOccurrences(of: "\n", with: " ")
        var words = text.components(separatedBy: " ")
        var index = 0
        for word in words {
            let misspelledRange =
                textChecker.rangeOfMisspelledWord(in: text,
                                                  range: NSRange(text.index(of: word)!.encodedOffset..<text.endIndex(of: word)!.encodedOffset),
                                                  startingAt: 0,
                                                  wrap: false,
                                                  language: "en_US")
            
            if misspelledRange.location != NSNotFound,
                let guesses = textChecker.guesses(forWordRange: misspelledRange,
                                                  in: text,
                                                  language: "en_US")
            {
                /*if word.contains("q") {
                 words[index] = word.replacingOccurrences(of: "q", with: "g")
                 }
                 else {*/
                if guesses.count > 0 {
                    words[index] = guesses.first!
                    text = words.joined(separator: " ")
                }
                //}
            }
            index = index + 1
        }
        return words.joined(separator: " ")
    }
    // Text checker
    
    
    // Image pre-processing for OCR
    
    open func preprocessImageForOCR(_ image:UIImage) -> UIImage {
        
        func getDodgeBlendImage(_ inputImage: UIImage) -> UIImage {
            let image  = GPUImagePicture(image: inputImage)
            let image2 = GPUImagePicture(image: inputImage)
            
            //First image
            
            let grayFilter      = GPUImageGrayscaleFilter()
            let invertFilter    = GPUImageColorInvertFilter()
            let blurFilter      = GPUImageBoxBlurFilter()
            let opacityFilter   = GPUImageOpacityFilter()
            
            blurFilter.blurRadiusInPixels = 9
            opacityFilter.opacity         = 0.93
            
            image?       .addTarget(grayFilter)
            grayFilter  .addTarget(invertFilter)
            invertFilter.addTarget(blurFilter)
            blurFilter  .addTarget(opacityFilter)
            
            opacityFilter.useNextFrameForImageCapture()
            
            //Second image
            
            let grayFilter2 = GPUImageGrayscaleFilter()
            
            image2?.addTarget(grayFilter2)
            
            grayFilter2.useNextFrameForImageCapture()
            
            //Blend
            
            let dodgeBlendFilter = GPUImageColorDodgeBlendFilter()
            
            grayFilter2.addTarget(dodgeBlendFilter)
            image2?.processImage()
            
            opacityFilter.addTarget(dodgeBlendFilter)
            
            dodgeBlendFilter.useNextFrameForImageCapture()
            image?.processImage()
            
            #if TARGET_IPHONE_SIMULATOR || TARGET_OS_IPHONE
            let orientationUp = UIImage.Orientation.up
            #else
            //GPUImage is using a re-definition of the UIImageOrientation for Mac compilation
            let orientationUp = UIImage.Orientation.up
            #endif
            
            var processedImage:UIImage? = dodgeBlendFilter.imageFromCurrentFramebuffer(with: orientationUp)
            
            while processedImage?.size == CGSize.zero || processedImage == nil {
                dodgeBlendFilter.useNextFrameForImageCapture()
                image?.processImage()
                processedImage = dodgeBlendFilter.imageFromCurrentFramebuffer(with: .up)
            }
            
            return processedImage!
        }
        
        let dodgeBlendImage        = getDodgeBlendImage(image)
        let picture                = GPUImagePicture(image: dodgeBlendImage)
        
        let medianFilter           = GPUImageMedianFilter()
        let openingFilter          = GPUImageOpeningFilter()
        let biliteralFilter        = GPUImageBilateralFilter()
        let firstBrightnessFilter  = GPUImageBrightnessFilter()
        let contrastFilter         = GPUImageContrastFilter()
        let secondBrightnessFilter = GPUImageBrightnessFilter()
        let thresholdFilter        = GPUImageLuminanceThresholdFilter()
        
        biliteralFilter.texelSpacingMultiplier      = 0.8
        biliteralFilter.distanceNormalizationFactor = 1.6
        firstBrightnessFilter.brightness            = -0.28
        contrastFilter.contrast                     = 2.35
        secondBrightnessFilter.brightness           = -0.08
        biliteralFilter.texelSpacingMultiplier      = 0.8
        biliteralFilter.distanceNormalizationFactor = 1.6
        thresholdFilter.threshold                   = 0.7
        
        picture?               .addTarget(medianFilter)
        medianFilter          .addTarget(openingFilter)
        openingFilter         .addTarget(biliteralFilter)
        biliteralFilter       .addTarget(firstBrightnessFilter)
        firstBrightnessFilter .addTarget(contrastFilter)
        contrastFilter        .addTarget(secondBrightnessFilter)
        secondBrightnessFilter.addTarget(thresholdFilter)
        
        thresholdFilter.useNextFrameForImageCapture()
        picture?.processImage()
        
        #if TARGET_IPHONE_SIMULATOR || TARGET_OS_IPHONE
        let orientationUp = UIImage.Orientation.up
        #else
        //GPUImage is using a re-definition of the UIImageOrientation for Mac compilation
        let orientationUp = UIImage.Orientation.up
        #endif
        
        var processedImage:UIImage? = thresholdFilter.imageFromCurrentFramebuffer(with: orientationUp)
        
        while processedImage == nil || processedImage?.size == CGSize.zero {
            thresholdFilter.useNextFrameForImageCapture()
            picture?.processImage()
            processedImage = thresholdFilter.imageFromCurrentFramebuffer(with: .up)
        }
        
        return processedImage!
        
    }
    
    func increaseContrast(_ image: UIImage) -> UIImage {
        let inputImage = CIImage(image: image)!
        let parameters = [
            "inputContrast": NSNumber(value: 1.5)
        ]
        let outputImage = inputImage.applyingFilter("CIColorControls", parameters: parameters)
        
        let context = CIContext(options: nil)
        let img = context.createCGImage(outputImage, from: outputImage.extent)!
        return UIImage(cgImage: img)
    }
}

//
//  UIImageExtensions.swift
//  Sketchnoting
//
//  Created by Aryobarzan on 15/03/2019.
//  Copyright © 2019 Aryobarzan. All rights reserved.
//

import UIKit
import VideoToolbox

extension UIImage {
var toGrayscale: UIImage {
    guard let ciImage = CIImage(image: self, options: nil) else { return self }
    let paramsColor: [String: AnyObject] = [kCIInputBrightnessKey: NSNumber(value: 0.0), kCIInputContrastKey: NSNumber(value: 1.0), kCIInputSaturationKey: NSNumber(value: 0.0)]
    let grayscale = ciImage.applyingFilter("CIColorControls", parameters: paramsColor)
    guard let processedCGImage = CIContext().createCGImage(grayscale, from: grayscale.extent) else { return self }
    return UIImage(cgImage: processedCGImage, scale: scale, orientation: imageOrientation)
}
var reduceNoise: UIImage? {
    guard let openGLContext = EAGLContext(api: .openGLES2) else { return self }
    let ciContext = CIContext(eaglContext: openGLContext)
    
    guard let noiseReduction = CIFilter(name: "CINoiseReduction") else { return self }
    noiseReduction.setValue(CIImage(image: self), forKey: kCIInputImageKey)
    noiseReduction.setValue(0.02, forKey: "inputNoiseLevel")
    noiseReduction.setValue(0.40, forKey: "inputSharpness")
    
    if let output = noiseReduction.outputImage,
        let cgImage = ciContext.createCGImage(output, from: output.extent) {
        return UIImage(cgImage: cgImage, scale: scale, orientation: imageOrientation)
    }
    
    return nil
}
func resize(toWidth width: CGFloat) -> UIImage? {
    let canvasSize = CGSize(width: width, height: CGFloat(ceil(width/size.width * size.height)))
    UIGraphicsBeginImageContextWithOptions(canvasSize, false, scale)
    defer { UIGraphicsEndImageContext() }
    draw(in: CGRect(origin: .zero, size: canvasSize))
    return UIGraphicsGetImageFromCurrentImageContext()
}
    
    // For drawing recognition
    public func resize(newSize: CGSize) -> UIImage {
        // create context - make sure we are on a 1.0 scale
        UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0);
        
        // draw with new size, get image, and return
        draw(in: CGRect(origin: CGPoint.zero, size: newSize))
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext();
        
        return newImage!
    }
    
    public func invert() -> UIImage {
        /*let beginImage = CIImage(image: self)
        if let filter = CIFilter(name: "CIColorInvert") {
            filter.setValue(beginImage, forKey: kCIInputImageKey)
            let newImage = UIImage(ciImage: filter.outputImage!)
            return newImage
        }
        return self*/
        var inverted = false
        let image = CIImage(cgImage: self.cgImage!)
        if let filter = CIFilter(name: "CIColorInvert") {
            filter.setDefaults()
            filter.setValue(image, forKey: kCIInputImageKey)

            let context = CIContext(options: nil)
            let imageRef = context.createCGImage(filter.outputImage!, from: image.extent)
            if imageRef != nil {
                var img = UIImage(cgImage: imageRef!)
                inverted = true
                return img
            }
            return self
        }

        if(!inverted) {
            return self
        }
    }
    public func blackAndWhite() -> UIImage? {
        guard let currentCGImage = self.cgImage else { return nil }
        let currentCIImage = CIImage(cgImage: currentCGImage)

        let filter = CIFilter(name: "CIColorMonochrome")
        filter?.setValue(currentCIImage, forKey: "inputImage")

        // set a gray value for the tint color
        filter?.setValue(CIColor(red: 0.7, green: 0.7, blue: 0.7), forKey: "inputColor")

        filter?.setValue(1.0, forKey: "inputIntensity")
        guard let outputImage = filter?.outputImage else { return nil }

        let context = CIContext()

        if let cgimg = context.createCGImage(outputImage, from: outputImage.extent) {
            return UIImage(cgImage: cgimg)
        }
        return nil
    }
    
    
    public func grayScalePixelBuffer() -> CVPixelBuffer? {
        // create gray scale pixel buffer
        var optionalPixelBuffer: CVPixelBuffer?
        guard CVPixelBufferCreate(kCFAllocatorDefault, 28, 28, kCVPixelFormatType_OneComponent8, nil, &optionalPixelBuffer) == kCVReturnSuccess else {
            return nil
        }
        
        guard let pixelBuffer = optionalPixelBuffer else {
            return nil
        }
        
        // draw image in pixel buffer
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer)
        let colorSpace = CGColorSpaceCreateDeviceGray()
        let context = CGContext(data: baseAddress, width: 28, height: 28, bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer), space: colorSpace, bitmapInfo: 0)
        context!.draw(cgImage!, in: CGRect(x: 0, y: 0, width: 28, height: 28))
        CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly)
        
        return pixelBuffer
    }
}
extension UIImage {
    func invertedImage() -> UIImage? {
        guard let cgImage = self.cgImage else { return nil }
        let ciImage = CoreImage.CIImage(cgImage: cgImage)
        guard let filter = CIFilter(name: "CIColorInvert") else { return nil }
        filter.setDefaults()
        filter.setValue(ciImage, forKey: kCIInputImageKey)
        let context = CIContext(options: nil)
        guard let outputImage = filter.outputImage else { return nil }
        guard let outputImageCopy = context.createCGImage(outputImage, from: outputImage.extent) else { return nil }
        return UIImage(cgImage: outputImageCopy, scale: self.scale, orientation: .up)
    }
}

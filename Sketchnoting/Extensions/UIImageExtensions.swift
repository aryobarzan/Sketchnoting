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
    
    func cropToRect(rect: CGRect!) -> UIImage? {

        let scaledRect = CGRect(x: rect.origin.x * self.scale, y: rect.origin.y * self.scale, width: rect.size.width * self.scale, height: rect.size.height * self.scale);


        guard let imageRef: CGImage = self.cgImage?.cropping(to:scaledRect)
        else {
            return nil
        }

        let croppedImage: UIImage = UIImage(cgImage: imageRef, scale: self.scale, orientation: self.imageOrientation)
        return croppedImage
    }
var toGrayscale: UIImage {
    guard let ciImage = CIImage(image: self, options: nil) else { return self }
    let paramsColor: [String: AnyObject] = [kCIInputBrightnessKey: NSNumber(value: 0.0), kCIInputContrastKey: NSNumber(value: 1.0), kCIInputSaturationKey: NSNumber(value: 0.0)]
    let grayscale = ciImage.applyingFilter("CIColorControls", parameters: paramsColor)
    guard let processedCGImage = CIContext().createCGImage(grayscale, from: grayscale.extent) else { return self }
    return UIImage(cgImage: processedCGImage, scale: scale, orientation: imageOrientation)
}
    
    // For drawing recognition
    public func resize(newSize: CGSize) -> UIImage {
        UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0);
        draw(in: CGRect(origin: CGPoint.zero, size: newSize))
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext();
        
        return newImage!
    }
    
    public func invert() -> UIImage {
        var inverted = false
        let image = CIImage(cgImage: self.cgImage!)
        if let filter = CIFilter(name: "CIColorInvert") {
            filter.setDefaults()
            filter.setValue(image, forKey: kCIInputImageKey)

            let context = CIContext(options: nil)
            let imageRef = context.createCGImage(filter.outputImage!, from: image.extent)
            if imageRef != nil {
                let img = UIImage(cgImage: imageRef!)
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
    
    // For handwriting and drawing recognition
    func merge(with topImage: UIImage) -> UIImage {
      let bottomImage = self

      UIGraphicsBeginImageContext(size)

      let areaSize = CGRect(x: 0, y: 0, width: bottomImage.size.width, height: bottomImage.size.height)
      bottomImage.draw(in: areaSize)

      topImage.draw(in: areaSize, blendMode: .normal, alpha: 1.0)

      let mergedImage = UIGraphicsGetImageFromCurrentImageContext()!
      UIGraphicsEndImageContext()
      return mergedImage
    }
    
    func mergeAlternatively(with secondImage: UIImage) -> UIImage {
        var image = self
        let newImageWidth = max(self.size.width, secondImage.size.width)
        let newImageHeight = max(self.size.height, secondImage.size.height)
        let newImageSize = CGSize(width: newImageWidth, height: newImageHeight)
        
        UIGraphicsBeginImageContextWithOptions(newImageSize, false, UIScreen.main.scale)
        
        let firstImageDrawX  = round((newImageSize.width - self.size.width)/2)
        let firstImageDrawY  = round((newImageSize.height - self.size.height)/2)
        let secondImageDrawX = round((newImageSize.width - secondImage.size.width)/2)
        let secondImageDrawY = round((newImageSize.height - secondImage.size.height)/2)
        
        self.draw(at: CGPoint(x: firstImageDrawX, y: firstImageDrawY))
        secondImage.draw(at: CGPoint(x: secondImageDrawX, y: secondImageDrawY))
        
        if let img = UIGraphicsGetImageFromCurrentImageContext() {
            image = img
        }
        UIGraphicsEndImageContext()
        
        return image
    }
    
    func add(image secondImage: NoteImage) -> UIImage {
        let image = self
        UIGraphicsBeginImageContext(size)
       
        let areaSize = CGRect(x: 0, y: 0, width: image.size.width, height: image.size.height)
        image.draw(in: areaSize)
        secondImage.image.draw(in: CGRect(x: secondImage.location.x-secondImage.size.width/2, y: secondImage.location.y-secondImage.size.height/2, width: secondImage.size.width, height: secondImage.size.height))

        let mergedImage = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        
        return mergedImage
    }
    
    func addText(drawText text: NoteTypedText) -> UIImage {
        let textColor = UIColor.black
        let textFont = UIFont(name: "Helvetica Bold", size: 10)!
        let image = self
        let scale = UIScreen.main.scale
        UIGraphicsBeginImageContextWithOptions(image.size, false, scale)

        let textFontAttributes = [
            NSAttributedString.Key.font: textFont,
            NSAttributedString.Key.foregroundColor: textColor,
            ] as [NSAttributedString.Key : Any]
        image.draw(in: CGRect(origin: CGPoint.zero, size: image.size))

        let rect = CGRect(origin: CGPoint(x: text.location.x-text.size.width/2, y: text.location.y-text.size.height/2), size: text.size)
        text.text.draw(in: rect, withAttributes: textFontAttributes)

        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        return newImage!
    }
}

//
//  SVGImageProcessorExtension.swift
//  Sketchnoting
//
//  Created by Aryobarzan on 18/09/2019.
//  Copyright © 2019 Aryobarzan. All rights reserved.
//

import UIKit
import Kingfisher
import PocketSVG
import SVGKit

struct SVGProcessor: ImageProcessor {
    
    let imgSize: CGSize?
    
    init(size: CGSize? = CGSize(width:250, height:250)) {
        imgSize = size
    }
    
    // `identifier` should be the same for processors with same properties/functionality
    // It will be used when storing and retrieving the image to/from cache.
    let identifier = "my.app.svg"
    
    // Convert input data/image to target image and return it.
    func process(item: ImageProcessItem, options: KingfisherParsedOptionsInfo) -> Image? {
        switch item {
        case .image(let image):
            //already an image
            return image
        case .data(let data):
            print(data)
            if let imageSVG : SVGKImage = SVGKImage(data: data) {
                return imageSVG.uiImage
            }
            return nil
            //return generateSVGImage(data: data, size: imgSize) ?? DefaultImageProcessor().process(item: item, options: options)
        }
    }
}

struct SVGCacheSerializer: CacheSerializer {
    
    func data(with image: Image, original: Data?) -> Data? {
        return original
    }
    
    func image(with data: Data, options: KingfisherParsedOptionsInfo) -> Image? {
        if let imageSVG : SVGKImage = SVGKImage(data: data) {
            return imageSVG.uiImage
        }
        return nil
        //return generateSVGImage(data: data) ?? image(with: data, options: options)
    }
}

func generateSVGImage(data: Data, size: CGSize? = CGSize(width:250, height:250)) -> UIImage?{
    let frame = CGRect(x: 0, y: 0, width: size!.width, height: size!.height)
    if let svgString = String(data: data, encoding: .utf8){
        let svgLayer = SVGLayer(layer: svgString)
        svgLayer.frame = frame
        return snapshotImage(for: svgLayer)
    }
    return nil
}

func snapshotImage(for layer: CALayer) -> UIImage? {
    UIGraphicsBeginImageContextWithOptions(layer.bounds.size, false, UIScreen.main.scale)
    guard let context = UIGraphicsGetCurrentContext() else { return nil }
    layer.render(in: context)
    let image = UIGraphicsGetImageFromCurrentImageContext()
    UIGraphicsEndImageContext()
    return image
}

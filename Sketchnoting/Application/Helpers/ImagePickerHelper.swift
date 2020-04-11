//
//  ImagePickerHelper.swift
//  Sketchnoting
//
//  Created by Aryobarzan on 04/04/2020.
//  Copyright © 2020 Aryobarzan. All rights reserved.
//

import UIKit
import Photos

import BSImagePicker

class ImagePickerHelper {
    static func displayImagePickerWithImageOutput(vc: UIViewController, completion: @escaping ([UIImage]) -> Void) {
        let imagePicker = ImagePickerController()

        vc.presentImagePicker(imagePicker,
           select: { (asset) in
        }, deselect: { (asset) in
        }, cancel: { (assets) in
        }, finish: { (assets) in
            var images = [UIImage]()
            let option = PHImageRequestOptions()
            option.version = .original
            option.isSynchronous = true
            for asset in assets {
                PHImageManager.default().requestImage(for: asset, targetSize: UIScreen.main.bounds.size, contentMode: .aspectFit, options: option) { (image, info) in
                    if let image = image {
                        images.append(image)
                    }
                }
            }
            completion(images)
        })
    }
}

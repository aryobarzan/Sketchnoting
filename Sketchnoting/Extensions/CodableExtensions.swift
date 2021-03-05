//
//  CodableExtensions.swift
//  Sketchnoting
//
//  Created by Aryobarzan on 11/04/2020.
//  Copyright © 2020 Aryobarzan. All rights reserved.
//

import UIKit
enum ImageEncodingQuality: CGFloat {
    case png = 0
    case jpeg = 1
}

extension KeyedEncodingContainer {

    mutating func encode(_ value: UIImage,
                         forKey key: KeyedEncodingContainer.Key,
                         quality: ImageEncodingQuality = .png) throws {
        var imageData: Data!
        switch quality {
        case .png:
            imageData = value.pngData()
        case .jpeg:
            imageData = value.jpegData(compressionQuality: 1)
        }
        try encode(imageData, forKey: key)
    }

}

extension KeyedDecodingContainer {

    public func decode(_ type: UIImage.Type, forKey key: KeyedDecodingContainer.Key) throws -> UIImage {
        let imageData = try decode(Data.self, forKey: key)
        if let image = UIImage(data: imageData) {
            return image
        } else {
            logger.info("Failed to decode note image.")
            return UIImage()
        }
    }

}

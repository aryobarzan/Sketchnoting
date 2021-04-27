//
//  Document.swift
//  Sketchnoting
//
//  Created by Aryobarzan on 26/02/2019.
//  Copyright © 2019 Aryobarzan. All rights reserved.
//

import UIKit
import Kingfisher
import SVGKit

protocol Visitable {
    func accept(visitor: DocumentVisitor)
}
protocol DocumentVisitor {
    func process(document: Document)
    func process(document: BioPortalDocument)
    func process(document: CHEBIDocument)
    func process(document: TAGMEDocument)
    func process(document: WATDocument)
    func process(document: ARDocument)
}

protocol DocumentDelegate {
    func documentHasChanged(document: Document)
}

enum DocumentType: String, Codable, CaseIterable {
    case TAGME
    case WAT
    case BioPortal
    case Chemistry
    case ALMAAR
    case Other
}

class Document: Codable, Visitable, Equatable, Hashable {
    
    var title: String
    private var description: String?
    var URL: String
    var documentType: DocumentType
    var isHidden: Bool
    
    var delegate: DocumentDelegate?
    
    private enum CodingKeys: String, CodingKey {
        case title = "Title"
        case description = "Description"
        case URL = "URL"
        case documentType = "DocumentType"
        case isHidden = "IsHidden"
    }
    
    init?(title: String, description: String?, URL: String, documentType: DocumentType){
        guard !title.isEmpty && !URL.isEmpty else {
            return nil
        }
        self.title = title
        self.description = description
        self.URL = URL
        self.documentType = documentType
        self.isHidden = false
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(title, forKey: .title)
        try container.encode(description, forKey: .description)
        try container.encode(URL, forKey: .URL)
        try container.encode(documentType, forKey: .documentType)
        try container.encode(isHidden, forKey: .isHidden)
    }
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        do {
            title = try container.decode(String.self, forKey: CodingKeys.title)
        } catch {
            logger.error(error)
            title = ""
        }
        do {
            description = try container.decode(String.self, forKey: .description)
        } catch {
            description = ""
        }
        do {
            isHidden = try container.decode(Bool.self, forKey: .isHidden)
        } catch {
            logger.error(error)
            isHidden = false
        }
        URL = try container.decode(String.self, forKey: .URL)
        documentType = DocumentType(rawValue: try container.decode(String.self, forKey: .documentType)) ?? .Other
    }
    
    func getDescription() -> String? {
        return description
    }
    
    func set(description: String?) {
        self.description = description
    }
    
    //MARK: Visitable
    func accept(visitor: DocumentVisitor) {
        visitor.process(document: self)
    }
    
    // MARK: Image resources downloading
    public enum DocumentImageType : String {
        case Standard
        case Map
        case Molecule
    }
    
    public func downloadImage(url: URL, type: DocumentImageType) {
        let cache = SKCacheManager.cache
        let key = type.rawValue + "-" + self.documentType.rawValue + "-" + self.title
        logger.info(key)
        let downloader = ImageDownloader.default
        if !url.absoluteString.lowercased().contains(".svg") {
            downloader.downloadImage(with: url, completionHandler:  { result in
                switch result {
                case .success(let value):
                    if value.originalData.count < 10000000 {
                        logger.info("Downloaded non-svg image for document: \(self.title)")
                        cache.store(value.image, original: value.originalData, forKey: key)
                        
                        self.reload()
                    }
                    else {
                        logger.error("Failed to download non-svg image for document due to large file size: \(self.title)")
                    }
                case .failure(let error):
                    logger.error("Failed to download non-svg image for document due to unknown reason: \(self.title)")
                    logger.error(error)
                }
            })
        }
        else {
            logger.info("SVG preview image detected.")
            if let svgImage = SVGKImage(contentsOf: url)?.uiImage {
                if let jpegData = svgImage.jpegData(compressionQuality: 0.8) {
                    if jpegData.count < 10000000 {
                        if let jpegImage = UIImage(data: jpegData) {
                            logger.info("Preview image from SVG image to jpeg image created.")
                            cache.store(jpegImage, forKey: key)
                            self.reload()
                        }
                        else {
                            logger.error("Could not create UIImage from jpeg data.")
                        }
                    }
                    else {
                        logger.error("Image bigger than 10MB, not stored.")
                    }
                }
                else {
                    logger.error("Could not get JPEG data from SVG image.")
                }
            }
            else {
                logger.error("Could not retrieve SVG image from URL content.")
            }
        }
    }
    
    internal func retrieveImage(type: DocumentImageType, completion:@escaping (Result<KFCrossPlatformImage?, KingfisherError>) -> ()) {
        
        let key = type.rawValue + "-" + self.documentType.rawValue + "-" + self.title
        let cache = SKCacheManager.cache
        cache.retrieveImageInDiskCache(forKey: key, completionHandler: { result in
            completion(result)
            })
    }
    
    public func reload() {
        delegate?.documentHasChanged(document: self)
    }
    
    static func == (lhs: Document, rhs: Document) -> Bool {
        if lhs.title == rhs.title && lhs.documentType == rhs.documentType {
            return true
        }
        return false
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(title)
        hasher.combine(documentType)
    }
}

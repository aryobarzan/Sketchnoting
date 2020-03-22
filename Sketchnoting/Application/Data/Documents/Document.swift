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
    func process(document: SpotlightDocument)
    func process(document: BioPortalDocument)
    func process(document: CHEBIDocument)
    func process(document: TAGMEDocument)
}

protocol DocumentDelegate {
    func documentHasChanged(document: Document)
}

enum DocumentType: String, Codable {
    case Spotlight
    case TAGME
    case BioPortal
    case Chemistry
    case Other
}

class Document: Codable, Visitable, Equatable {
    
    var title: String
    var description: String?
    var URL: String
    var documentType: DocumentType
    
    var delegate: DocumentDelegate?
    
    private enum CodingKeys: String, CodingKey {
        case title = "Title"
        case description = "Description"
        case URL = "URL"
        case documentType = "DocumentType"
    }
    
    init?(title: String, description: String?, URL: String, documentType: DocumentType){
        guard !title.isEmpty && !URL.isEmpty else {
            return nil
        }
        self.title = title
        self.description = description
        self.URL = URL
        self.documentType = documentType
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(title, forKey: .title)
        try container.encode(description, forKey: .description)
        try container.encode(URL, forKey: .URL)
        try container.encode(documentType, forKey: .documentType)
    }
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        do {
            title = try container.decode(String.self, forKey: CodingKeys.title)
        } catch {
            print(error)
            title = ""
        }
        do {
            description = try container.decode(String.self, forKey: .description)
        } catch {
            print(error)
            print("Note description decoding failed.")
            description = ""
        }
        URL = try container.decode(String.self, forKey: .URL)
        documentType = DocumentType(rawValue: try container.decode(String.self, forKey: .documentType)) ?? .Other
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
        let key = type.rawValue + "-" + self.title
        let downloader = ImageDownloader.default
        if !url.absoluteString.lowercased().contains(".svg") {
            downloader.downloadImage(with: url) { result in
                switch result {
                case .success(let value):
                    if value.originalData.count < 10000000 {
                        cache.store(value.image, original: value.originalData, forKey: key)
                        self.reload()
                    }
                case .failure(let error):
                    log.error(error)
                }
            }
        }
        else {
            log.info("SVG preview image detected.")
            if let svgImage = SVGKImage(contentsOf: url)?.uiImage {
                if let jpegData = svgImage.jpegData(compressionQuality: 0.8) {
                    if jpegData.count < 10000000 {
                        if let jpegImage = UIImage(data: jpegData) {
                            log.info("Preview image from SVG image to jpeg image created.")
                            cache.store(jpegImage, forKey: key)
                            self.reload()
                        }
                        else {
                            log.error("Could not create UIImage from jpeg data.")
                        }
                    }
                    else {
                        log.error("Image bigger than 10MB, not stored.")
                    }
                }
                else {
                    log.error("Could not get JPEG data from SVG image.")
                }
            }
            else {
                log.error("Could not retrieve SVG image from URL content.")
            }
        }
    }
    
    internal func retrieveImage(type: DocumentImageType, completion:@escaping (Result<KFCrossPlatformImage?, KingfisherError>) -> ()) {
        let key = type.rawValue + "-" + self.title
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
}

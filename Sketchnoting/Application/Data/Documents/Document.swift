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

enum DocumentType: String, Codable {
    case Spotlight
    case TAGME
    case BioPortal
    case Chemistry
    case Other
}

class Document: Codable, Visitable, Equatable {
    static func == (lhs: Document, rhs: Document) -> Bool {
        if lhs.title == rhs.title && lhs.documentType == rhs.documentType {
            return true
        }
        return false
    }
    
    var title: String
    var description: String?
    var URL: String
    var documentType: DocumentType
    var previewImage: UIImage?
    
    var delegate: DocumentDelegate?
    
    private enum CodingKeys: String, CodingKey {
        case title = "Title"
        case description = "Description"
        case URL = "URL"
        case documentType = "DocumentType"
    }
    
    init?(title: String, description: String?, URL: String, documentType: DocumentType, previewImage: UIImage?){
        guard !title.isEmpty && !URL.isEmpty else {
            return nil
        }
        self.title = title
        self.description = description
        self.URL = URL
        self.documentType = documentType
        self.previewImage = previewImage
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
        
        loadPreviewImage()
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
        let cache = ImageCache.default
        let key = type.rawValue + "-" + self.title
        let downloader = ImageDownloader.default
        if !url.absoluteString.lowercased().contains(".svg") {
            downloader.downloadImage(with: url) { result in
                switch result {
                case .success(let value):
                    cache.store(value.image, original: value.originalData, forKey: key)
                    self.reload()
                case .failure(let error):
                    print(error)
                }
            }
        }
        else {
            log.info("SVG preview image detected.")
            if let svgImage = SVGKImage(contentsOf: url)?.uiImage {
                if let jpegData = svgImage.jpegData(compressionQuality: 1) {
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
                    log.error("Could not get JPEG data from SVG image.")
                }
            }
            else {
                log.error("Could not retrieve SVG image from URL content.")
            }
        }
    }
    
    internal func retrieveImage(type: DocumentImageType, completion:@escaping (Result<Image?, KingfisherError>) -> ()) {
        let key = type.rawValue + "-" + self.title
        let cache = ImageCache.default
        cache.retrieveImageInDiskCache(forKey: key, completionHandler: { result in
            completion(result)
            })
        /*
         let processor = SVGProcessor()
         let serializer = SVGCacheSerializer()
         ImageCache.default.retrieveImageInDiskCache(forKey: key, options: [.processor(processor), .forceRefresh, .cacheSerializer(serializer), .waitForCache]) { result in
            switch result {
            case .success(let value):
                if value != nil {
                    log.info("Image found for key \(key).")
                    DispatchQueue.main.async {
                        self.previewImage = value!
                        print(self.previewImage)
                    }
                }
            case .failure(let error):
                log.error("No image found for key \(key).")
                print(error)
            }
        }*/
    }
    internal func loadPreviewImage() {
        self.retrieveImage(type: .Standard, completion: { result in
            switch result {
            case .success(let value):
                if value != nil {
                    log.info("Preview image found for document \(self.title).")
                    DispatchQueue.main.async {
                        self.previewImage = value!
                    }
                }
            case .failure(let error):
                log.error("No preview image found for document \(self.title).")
                print(error)
            }
        })
    }
    
    public func reload() {
        loadPreviewImage()
        delegate?.documentHasChanged(document: self)
    }
}

protocol DocumentDelegate {
    func documentHasChanged(document: Document)
}

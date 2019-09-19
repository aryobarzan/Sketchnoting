//
//  Sketchnote.swift
//  Sketchnoting
//
//  Created by Aryobarzan on 26/02/2019.
//  Copyright © 2019 Aryobarzan. All rights reserved.
//

import UIKit
import PDFKit


protocol SketchnoteDelegate {
    func sketchnoteHasNewDocument(sketchnote: Sketchnote, document: Document)
    func sketchnoteHasRemovedDocument(sketchnote: Sketchnote, document: Document)
    func sketchnoteDocumentHasChanged(sketchnote: Sketchnote, document: Document)
    func sketchnoteHasChanged(sketchnote: Sketchnote)
}

class Sketchnote: Note, Equatable, DocumentVisitor, Comparable, DocumentDelegate {
    
    var delegate: SketchnoteDelegate?
    
    var id: String!
    private var title: String!
    var creationDate: Date!
    var updateDate: Date?
    var image: UIImage?
    var documents: [Document]!
    var drawings: [String]? // recognized drawings' labels
    var drawingViewRects: [CGRect]?
    var paths: NSMutableArray?
    var textDataArray: [TextData]!
    var tags: [Tag]!
    
    var sharedByDevice: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case title
        case creationDate
        case updateDate
        case image
        case relatedDocuments = "relatedDocuments"
        case drawings = "drawings"
        case drawingViewRects = "drawingViewRects"
        case tags = "tags"
    }
    
    //MARK: Initialization
    
    init?(image: UIImage?, relatedDocuments: [Document]?, drawings: [String]?) {
        self.id = UUID().uuidString
        self.title = "Untitled"
        self.creationDate = Date.init(timeIntervalSinceNow: 0)
        self.documents = relatedDocuments ?? [Document]()
        self.drawings = drawings ?? [String]()
        self.image = image
        self.textDataArray = [TextData]()
        self.tags = [Tag]()
    }
    
    //MARK: Persistence
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(creationDate.timeIntervalSince1970, forKey: .creationDate)
        try container.encode(updateDate?.timeIntervalSince1970, forKey: .updateDate)
        do {
            try container.encode(documents, forKey: .relatedDocuments)
        } catch {
        }
        
        try container.encode(drawings, forKey: .drawings)
        try container.encode(drawingViewRects, forKey: .drawingViewRects)
        if image != nil {
            let imageData: Data = image!.pngData()!
            let strBase64 = imageData.base64EncodedString(options: .lineLength64Characters)
            try container.encode(strBase64, forKey: .image)
        }
        try container.encode(tags, forKey: .tags)
    }
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try? container.decode(String.self, forKey: .id)
        title = try? container.decode(String.self, forKey: .title)
        if title == nil || title.isEmpty {
            title = "Untitled"
        }
        creationDate = Date(timeIntervalSince1970: try container.decode(TimeInterval.self, forKey: .creationDate))
        do {
            _ = try container.decode(TimeInterval.self, forKey: .updateDate)
            updateDate = Date(timeIntervalSince1970: try container.decode(TimeInterval.self, forKey: .updateDate))
        } catch {
        }

        var docsArrayForType = try container.nestedUnkeyedContainer(forKey: .relatedDocuments)
        var docs = [Document]()
        var docsArray = docsArrayForType
        do {
            while(!docsArrayForType.isAtEnd) {
                let doc = try docsArrayForType.nestedContainer(keyedBy: DocumentTypeKey.self)
                let t = try doc.decode(DocumentType.self, forKey: DocumentTypeKey.type)
                switch t {
                case .Spotlight:
                    docs.append(try docsArray.decode(SpotlightDocument.self))
                    break
                case .BioPortal:
                    docs.append(try docsArray.decode(BioPortalDocument.self))
                    break
                case .Chemistry:
                    docs.append(try docsArray.decode(CHEBIDocument.self))
                    break
                case .TAGME:
                    docs.append(try docsArray.decode(TAGMEDocument.self))
                    break
                case .Other:
                    docs.append(try docsArray.decode(Document.self))
                    break
                }
            }
        } catch {
            log.error("Decoding a note's documents failed.")
            print(error)
        }
        self.documents = docs
        for doc in documents {
            doc.delegate = self
        }
        
        drawings = try? container.decode([String].self, forKey: .drawings)
        drawingViewRects = try? container.decode([CGRect].self, forKey: .drawingViewRects)
        do {
            let strBase64: String = try container.decode(String.self, forKey: .image)
            let dataDecoded: Data = Data(base64Encoded: strBase64, options: .ignoreUnknownCharacters)!
            image = UIImage(data: dataDecoded)
        } catch {
        }
        
        tags = try? container.decode([Tag].self, forKey: .tags)
        if tags == nil {
            tags = [Tag]()
        }
        
        self.loadPaths()
        self.loadTextDataArray()
        log.info("Sketchnote " + self.id + " decoded.")
    }
    
    private enum DocumentTypeKey : String, CodingKey {
        case type = "DocumentType"
    }
    private enum DocumentTypes : String, Decodable {
        case spotlight = "Spotlight"
        case bioportal = "BioPortal"
        case chebi = "CHEBI"
        case tagme = "TAGME"
    }
    
    public func save() {
        let encoder = JSONEncoder()
        
        if let encoded = try? encoder.encode(self) {
            UserDefaults.sketchnotes.set(encoded, forKey: self.id)
            log.info("Note \(self.id ?? "") saved.")
            if self.paths != nil {
                self.savePaths()
            }
            self.saveTextDataArray()
        }
        else {
            log.error("Encoding failed for note " + id + ".")
        }
    }
    public func savePaths() {
        if self.paths != nil {
            let DocumentsDirectory = FileManager().urls(for: .documentDirectory, in: .userDomainMask).first!
            let ArchiveURLPathArray = DocumentsDirectory.appendingPathComponent("NotePaths-" + self.id)
            if let encoded = try? NSKeyedArchiver.archivedData(withRootObject: self.paths as Any, requiringSecureCoding: false) {
                try! encoded.write(to: ArchiveURLPathArray)
                log.info("Note " + id + " paths saved.")
            }
            else {
                log.error("Failed to encode paths for note " + id + ".")
            }
        }
    }
    private func loadPaths() {
        let DocumentsDirectory = FileManager().urls(for: .documentDirectory, in: .userDomainMask).first!
        let ArchiveURLPathArray = DocumentsDirectory.appendingPathComponent("NotePaths-" + self.id)
        guard let codedData = try? Data(contentsOf: ArchiveURLPathArray) else { return }
        guard let data = ((try? NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(codedData) as?
            NSMutableArray) as NSMutableArray??) else {
                log.error("Failed to load paths for note " + id + ".")
                return }
        self.paths = data
        log.info("Paths for note " + id + " loaded.")
    }
    public func saveTextDataArray() {
        let DocumentsDirectory = FileManager().urls(for: .documentDirectory, in: .userDomainMask).first!
        let ArchiveURLPathArray = DocumentsDirectory.appendingPathComponent("NoteTextDataArray-" + self.id)
        if let encoded = try? NSKeyedArchiver.archivedData(withRootObject: self.textDataArray as Any, requiringSecureCoding: false) {
            try! encoded.write(to: ArchiveURLPathArray)
            log.info("Note " + id + " text data array saved.")
        }
        else {
            log.error("Failed to encode text data array for note " + id + ".")
        }
    }
    private func loadTextDataArray() {
        let DocumentsDirectory = FileManager().urls(for: .documentDirectory, in: .userDomainMask).first!
        let ArchiveURLPathArray = DocumentsDirectory.appendingPathComponent("NoteTextDataArray-" + self.id)
        guard let codedData = try? Data(contentsOf: ArchiveURLPathArray) else { return }
        guard let data = ((try? NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(codedData) as?
            [TextData]) as [TextData]??) else {
                log.error("Failed to load text data array for note " + id + ".")
                return }
        self.textDataArray = data
        log.info("Text data array for note " + id + " loaded.")
    }
    
    public func delete() {
        clearPaths()
        clearTextData()
        UserDefaults.sketchnotes.removeObject(forKey: id)
    }
    
    public func clearPaths() {
        do {
            let DocumentsDirectory = FileManager().urls(for: .documentDirectory, in: .userDomainMask).first!
            let ArchiveURLPathArray = DocumentsDirectory.appendingPathComponent("NotePaths-" + id)
            try FileManager().removeItem(atPath: ArchiveURLPathArray.absoluteString)
        } catch {
        }
        self.paths = nil
    }
    
    public func clearTextData() {
        do {
            let DocumentsDirectory = FileManager().urls(for: .documentDirectory, in: .userDomainMask).first!
            let ArchiveURLPathArray = DocumentsDirectory.appendingPathComponent("NoteTextDataArray-" + id)
            try FileManager().removeItem(atPath: ArchiveURLPathArray.absoluteString)
        } catch {
        }
        self.textDataArray = [TextData]()
    }
    
    //MARK: updating data
    public func clear() {
        documents = [Document]()
        drawings = [String]()
        clearTextData()
        clearPaths()
    }
    
    func addDocument(document: Document) {
        if documents == nil {
            documents = [Document]()
        }
        if !documents!.contains(document) && isDocumentValid(document: document) {
            documents!.append(document)
            document.delegate = self
            self.delegate?.sketchnoteHasNewDocument(sketchnote: self, document: document)
        }
    }
    
    private func isDocumentValid(document: Document) -> Bool {
        if DocumentsManager.isHidden(document: document) {
            return false
        }
        if let doc = document as? BioPortalDocument {
            let blacklistedBioPortalTerms = ["place", "city", "populated", "country", "capital", "location", "state", "town"]
            for term in blacklistedBioPortalTerms {
                if doc.description?.lowercased().contains(term) ?? false {
                    return false
                }
            }
        }
        var existingDocumentsToRemove = [Document]()
        for doc in documents {
            if doc.title.lowercased().contains(document.title.lowercased()) && doc.title.lowercased() != document.title.lowercased() {
                return false
            }
            else if document.title.lowercased().contains(doc.title.lowercased()) && document.title.lowercased() != doc.title.lowercased() {
                existingDocumentsToRemove.append(doc)
            }
        }
        for doc in existingDocumentsToRemove {
            self.removeDocument(document: doc)
        }
        return true
    }
    
    func removeDocument(document: Document) {
        if documents == nil {
            documents = [Document]()
        }
        else if documents!.contains(document) {
            documents.removeAll{$0 == document}
            self.delegate?.sketchnoteHasRemovedDocument(sketchnote: self, document: document)
        }
    }
    
    func setDocumentPreviewImage(document: Document, image: UIImage) {
        if self.documents.contains(document) {
            document.previewImage = image
            self.delegate?.sketchnoteDocumentHasChanged(sketchnote: self, document: document)
        }
    }
    func setDocumentMapImage(document: Document, image: UIImage) {
        if self.documents.contains(document) {
            if document is TAGMEDocument {
                (document as! TAGMEDocument).mapImage = image
                self.delegate?.sketchnoteDocumentHasChanged(sketchnote: self, document: document)
            }
            else if document is SpotlightDocument {
                (document as! SpotlightDocument).mapImage = image
                self.delegate?.sketchnoteDocumentHasChanged(sketchnote: self, document: document)
            }
        }
    }
    func setDocumentMoleculeImage(document: CHEBIDocument, image: UIImage) {
        if self.documents.contains(document) {
            document.moleculeImage = image
            self.delegate?.sketchnoteDocumentHasChanged(sketchnote: self, document: document)
        }
    }
    
    func documentHasChanged(document: Document) {
        self.delegate?.sketchnoteDocumentHasChanged(sketchnote: self, document: document)
    }

    // This function only stores a recognized drawing's label for a note. The drawing itself (i.e. an image) is not stored.
    // Only the label is necessary, as it is used for search results.
    func addDrawing(drawing: String) {
        var exists = false
        if drawings == nil {
            drawings = [String]()
        }
        for d in drawings! {
            if d == drawing.lowercased() {
                exists = true
                break
            }
        }
        if !exists {
            drawings!.append(drawing.lowercased())
        }
    }
    
    func addDrawingViewRect(rect: CGRect) {
        var exists = false
        if drawingViewRects == nil {
            drawingViewRects = [CGRect]()
        }
        for r in drawingViewRects! {
            if r == rect {
                exists = true
                break
            }
        }
        if !exists {
            drawingViewRects!.append(rect)
        }
    }
    
    func removeDrawingViewRect(rect: CGRect) {
        if drawingViewRects != nil {
            if drawingViewRects!.contains(rect) {
                drawingViewRects!.removeAll{$0 == rect}
            }
        }
    }
    
    func setUpdateDate() {
        self.updateDate = Date.init(timeIntervalSinceNow: 0)
    }
    
    func setTitle(title: String) {
        if title.isEmpty || title.count < 1 {
            self.title = "Untitled"
        }
        else {
            self.title = title
        }
    }
    func getTitle() -> String {
        return self.title
    }
    
    //MARK: recognized text
    public func getText(raw: Bool = false) -> String {
        var text: String = ""
        if textDataArray != nil {
            if !raw {
                for textData in textDataArray {
                    text = text + " " + textData.spellchecked
                }
            }
            else {
                for textData in textDataArray {
                    text = text + " " + textData.original
                }
            }
        }
        return text
    }
    
    // MARK: Search
    var matchesSearch = false
    var currentSearchFilter : SearchFilter?
    public func applySearchFilters(filters: [SearchFilter]) -> Bool {
        matchesSearch = false
        var matches = 0
        for filter in filters {
            switch filter.type {
            case .All:
                if (self.title.lowercased().contains(filter.term) || self.getText().lowercased().contains(filter.term)) || (self.drawings?.contains(filter.term) ?? false) {
                    matches += 1
                }
                else {
                    currentSearchFilter = filter
                    if let documents = self.documents {
                        for doc in documents {
                            doc.accept(visitor: self)
                            if matchesSearch {
                                matches += 1
                            }
                        }
                    }
                }
                break
            case .Text:
                if (self.title.lowercased().contains(filter.term) || self.getText().lowercased().contains(filter.term)) {
                    matches += 1
                }
                break
            case .Drawing:
                if self.drawings?.contains(filter.term) ?? false {
                    matches += 1
                }
                break
            case .Document:
                currentSearchFilter = filter
                if let documents = self.documents {
                    for doc in documents {
                        doc.accept(visitor: self)
                        if matchesSearch {
                            matches += 1
                        }
                    }
                }
                break
            }
        }
        return matches == filters.count
    }
    func process(document: Document) {
        let _ = self.processBaseDocumentSearch(document: document)
    }
    
    func process(document: SpotlightDocument) {
        if !processBaseDocumentSearch(document: document) {
            if let label = document.label {
                if label.lowercased().contains(currentSearchFilter!.term) {
                    matchesSearch = true
                }
            }
            if let types = document.types {
                for type in types {
                    if type.lowercased().contains(currentSearchFilter!.term) {
                        matchesSearch = true
                        break
                    }
                }
            }
        }
    }
    func process(document: TAGMEDocument) {
        if !processBaseDocumentSearch(document: document) {
            if let spot = document.spot {
                if spot.lowercased().contains(currentSearchFilter!.term) {
                    matchesSearch = true
                }
            }
            if let categories = document.categories {
                for category in categories {
                    if category.lowercased().contains(currentSearchFilter!.term) {
                        matchesSearch = true
                        break
                    }
                }
            }
        }
    }
    
    func process(document: BioPortalDocument) {
        let _ = processBaseDocumentSearch(document: document)
    }
    
    func process(document: CHEBIDocument) {
        let _ = processBaseDocumentSearch(document: document)
    }
    
    private func processBaseDocumentSearch(document: Document) -> Bool {
        if document.title.lowercased().contains(currentSearchFilter!.term) {
            matchesSearch = true
            return true
        }
        else if let description = document.description {
            if description.lowercased().contains(currentSearchFilter!.term) {
                matchesSearch = true
                return true
            }
        }
        return false
    }
    
    // MARK: PDF Generation
    
    func createPDF() -> Data? {
        if let image = self.image {
            let pdfMetaData = [
                kCGPDFContextCreator: "Sketchnoting iOS App",
                kCGPDFContextAuthor: UIDevice.current.name
            ]
            let format = UIGraphicsPDFRendererFormat()
            format.documentInfo = pdfMetaData as [String: Any]
            
            let pageWidth = image.size.width
            let pageHeight = image.size.height
            let pageRect = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
            
            let renderer = UIGraphicsPDFRenderer(bounds: pageRect, format: format)
            let data = renderer.pdfData { (context) in
                context.beginPage()
                image.draw(at: CGPoint(x: 0, y: 0))
            }
            return data
        }
        return nil
    }
    
    // MARK: Comparable, equatable

    static func == (lhs: Sketchnote, rhs: Sketchnote) -> Bool {
        if lhs.id == rhs.id {
            return true
        }
        return false
    }
    
    static func < (lhs: Sketchnote, rhs: Sketchnote) -> Bool {
        return lhs.creationDate < rhs.creationDate
    }
}

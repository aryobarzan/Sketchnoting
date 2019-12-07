//
//  Sketchnote.swift
//  Sketchnoting
//
//  Created by Aryobarzan on 26/02/2019.
//  Copyright © 2019 Aryobarzan. All rights reserved.
//

import UIKit
import PDFKit
import PencilKit

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
    var pages: [NotePage]!
    var documents: [Document]!
    var tags: [Tag]!
    var activePageIndex = 0
    var helpLinesType: HelpLinesType!
    
    var sharedByDevice: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case title
        case creationDate
        case updateDate
        case relatedDocuments = "relatedDocuments"
        case tags = "tags"
        case activePageIndex
        case helpLinesType = "helpLinesType"
    }
    
    //MARK: Initialization
    
    init?(relatedDocuments: [Document]?) {
        self.id = UUID().uuidString
        self.title = "Untitled"
        self.creationDate = Date.init(timeIntervalSinceNow: 0)
        self.documents = relatedDocuments ?? [Document]()
        self.pages = [NotePage]()
        self.tags = [Tag]()
        self.helpLinesType = .None
        
        let firstPage = NotePage()
        self.pages.append(firstPage)
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
        try container.encode(tags, forKey: .tags)
        try container.encode(activePageIndex, forKey: .activePageIndex)
        try container.encode(helpLinesType, forKey: .helpLinesType)
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
        tags = try? container.decode([Tag].self, forKey: .tags)
        if tags == nil {
            tags = [Tag]()
        }
        activePageIndex = try container.decode(Int.self, forKey: .activePageIndex)
        helpLinesType = try? container.decode(HelpLinesType.self, forKey: .helpLinesType)
        if helpLinesType == nil {
            helpLinesType = .None
        }
        
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
    
    private let serializationQueue = DispatchQueue(label: "SerializationQueue", qos: .background)
    public func save() {
        serializationQueue.async {
            let encodedData = self.packageNoteAsData()
            let sketchnotesDirectory = NotesManager.getSketchnotesDirectory()
            try? encodedData!.write(to: sketchnotesDirectory.appendingPathComponent(self.id + ".sketchnote"))
        }
    }
    
    public func packageNoteAsData() -> Data? {
        var data = [Data]()
        // Encode metadata
        let metaDataEncoder = JSONEncoder()
        if let encodedMetaData = try? metaDataEncoder.encode(self) {
            data.append(encodedMetaData)
            log.info("Note \(self.id ?? "") meta data encoded.")
        }
        else {
            log.error("Encoding failed for note " + self.id + ".")
        }
        // Encode note pages
        if let encodedPages = try? NSKeyedArchiver.archivedData(withRootObject: self.pages as Any, requiringSecureCoding: false) {
            data.append(encodedPages)
            log.info("Note " + self.id + " pages encoded.")
        }
        let dataEncoded = try? NSKeyedArchiver.archivedData(withRootObject: data, requiringSecureCoding: false)
        return dataEncoded
    }
    
    public func duplicate() -> Sketchnote {
        let documents = self.documents
        let duplicate = Sketchnote(relatedDocuments: documents)!
        duplicate.setTitle(title: self.getTitle() + " #2")
        duplicate.tags = self.tags
        duplicate.save()
        return duplicate
    }
    
    //MARK: updating data
    public func clear() {
        documents = [Document]()
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
        for page in pages {
            text = text + page.getText()
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
                var isInText = false
                if (self.title.lowercased().contains(filter.term) || self.getText().lowercased().contains(filter.term)) {
                    matches += 1
                    isInText = true
                }
                var isInDrawings = false
                    for page in pages {
                                       if page.drawingLabels?.contains(filter.term) ?? false {
                                           matches += 1
                                        isInDrawings = true
                                           break
                                       }
                                   }
                if !isInText && !isInDrawings {
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
                for page in pages {
                    if page.drawingLabels?.contains(filter.term) ?? false {
                        matches += 1
                        break
                    }
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
        if let pages = pages {
            if pages.count > 0 {
                let pdfWidth = UIScreen.main.bounds.width
                let pdfHeight = pages[0].canvasDrawing.bounds.maxY + 100
                
                let bounds = CGRect(x: 0, y: 0, width: pdfWidth, height: pdfHeight)
                let mutableData = NSMutableData()
                UIGraphicsBeginPDFContextToData(mutableData, bounds, nil)
                for page in pages {
                    UIGraphicsBeginPDFPage()
                        
                    var yOrigin: CGFloat = 0
                    let imageHeight: CGFloat = 1024
                    while yOrigin < bounds.maxY {
                        let imgBounds = CGRect(x: 0, y: yOrigin, width: UIScreen.main.bounds.width, height: min(imageHeight, bounds.maxY - yOrigin))
                        UITraitCollection(userInterfaceStyle: .light).performAsCurrent {
                            let image = page.canvasDrawing.image(from: imgBounds, scale: 2)
                            image.draw(in: imgBounds)
                            yOrigin += imageHeight
                        }
                    }
                }
                UIGraphicsEndPDFContext()
                return mutableData as Data
            }
            return nil
        }
        return nil
    }
    
    // MARK: Page helper functions
    
    public func getCurrentPage() -> NotePage {
        if activePageIndex >= pages.count {
            activePageIndex = 0
        }
        if pages.count == 0 {
            pages.append(NotePage())
        }
        return pages[activePageIndex]
    }
    
    public func getPreviewImage() -> UIImage? {
        if let pages = pages {
            if pages.count > 0 {
                return pages[0].image
            }
            return nil
        }
        return nil
    }
    
    public func hasNextPage() -> Bool {
        return activePageIndex < pages.count - 1
    }
    
    public func hasPreviousPage() -> Bool {
        return activePageIndex > 0
    }
    
    public func nextPage() {
        if hasNextPage() {
            activePageIndex += 1
        }
    }
    
    public func previousPage() {
        if hasPreviousPage() {
            activePageIndex -= 1
        }
    }
    
    public func deletePage(index: Int) {
        if pages.count > 1 {
            if index >= 0 && index < pages.count {
                pages.remove(at: index)
                if activePageIndex == index {
                    activePageIndex -= 1
                }
            }
        }
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
    
    // MARK: Compare similarity of content
    
    public func similarTo(note: Sketchnote) -> Double {
        var similarity = 0.0
        if self.getTitle().lowercased() == note.getTitle().lowercased() {
            similarity += 0.2
        }
        for document in documents {
            for other in note.documents {
                if document.title.lowercased() == other.title.lowercased() {
                    similarity += 5
                }
                /*if let description = document.description, let otherDescription = other.description {
                    let distance = description.levenshtein(otherDescription)
                    if distance == 0 {
                        similarity += 5
                    }
                    else {
                        similarity += Double(5 * (1 / distance))
                    }
                }*/
                if document.documentType == other.documentType {
                    similarity += 0.5
                    switch document.documentType {
                    case .Spotlight:
                        let d1 = document as! SpotlightDocument
                        let d2 = other as! SpotlightDocument
                        if let types = d1.types, let otherTypes = d2.types {
                            let commonTypes = SketchnotingUtilities.commonElements(types, otherTypes)
                            similarity += Double(3 * commonTypes.count)
                        }
                    case .TAGME:
                        let d1 = document as! TAGMEDocument
                        let d2 = other as! TAGMEDocument
                        if let categories = d1.categories, let otherCategories = d2.categories {
                            let commonCategories = SketchnotingUtilities.commonElements(categories, otherCategories)
                            similarity += Double(3 * commonCategories.count)
                        }
                    case .BioPortal:
                        break
                    case .Chemistry:
                        break
                    case .Other:
                        break
                    }
                }
            }
        }
        return similarity
    }
    
    
    public func mergeWith(note: Sketchnote) {
        if note != self {
            for page in note.pages {
                self.pages.append(page)
            }
            self.mergeTagsWith(note: note)
            self.setUpdateDate()
            self.save()
            
            NotesManager.delete(note: note)
        }
    }
    
    public func mergeTagsWith(note: Sketchnote) {
        for tag in note.tags {
            if !self.tags.contains(tag) {
                self.tags.append(tag)
            }
        }
        self.save()
    }
}

public enum HelpLinesType: Codable {
    case None
    case Horizontal
    case Grid
    
    enum Key: CodingKey {
        case rawValue
    }
    
    enum CodingError: Error {
        case unknownValue
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: Key.self)
        let rawValue = try container.decode(Int.self, forKey: .rawValue)
        switch rawValue {
        case 0:
            self = .None
        case 1:
            self = .Horizontal
        case 2:
            self = .Grid
        default:
            throw CodingError.unknownValue
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: Key.self)
        switch self {
        case .None:
            try container.encode(0, forKey: .rawValue)
        case .Horizontal:
            try container.encode(1, forKey: .rawValue)
        case .Grid:
            try container.encode(2, forKey: .rawValue)
        }
    }
}

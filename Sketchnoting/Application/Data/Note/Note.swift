//
//  Note.swift
//  Sketchnoting
//
//  Created by Aryobarzan on 07/02/2020.
//  Copyright © 2020 Aryobarzan. All rights reserved.
//

import UIKit
import PDFKit
import PencilKit

protocol NoteDelegate {
    func noteHasNewDocument(note: Note, document: Document)
    func noteHasRemovedDocument(note: Note, document: Document)
    func noteDocumentHasChanged(note: Note, document: Document)
    func noteHasChanged(note: Note)
}

class Note: File, DocumentVisitor, DocumentDelegate {
    var pages: [NotePage]
    private var documents: [Document]
    var hiddenDocuments: [Document]
    var tags: [Tag]
    var activePageIndex = 0
    var helpLinesType: HelpLinesType
    var tagmeEpsilon: Float = 0.3
    
    var sharedByDevice: String?
    
    var delegate: NoteDelegate?
    
    init(name: String, parent: String?, documents: [Document]?) {
        self.documents = documents ?? [Document]()
        self.hiddenDocuments = [Document]()
        self.pages = [NotePage]()
        self.tags = [Tag]()
        self.helpLinesType = .None
        let firstPage = NotePage()
        self.pages.append(firstPage)
        super.init(name: name, parent: parent)
    }
    
    //Codable
    enum NoteCodingKeys: String, CodingKey {
        case documents = "documents"
        case hiddenDocuments = "hiddenDocuments"
        case tags = "tags"
        case activePageIndex
        case helpLinesType = "helpLinesType"
        case pages = "pages"
        case tagmeEpsilon = "tagmeEpsilon"
    }
    private enum DocumentTypeKey : String, CodingKey {
        case type = "DocumentType"
    }
    private enum DocumentTypes : String, Decodable {
        case spotlight = "Spotlight"
        case bioportal = "BioPortal"
        case chebi = "CHEBI"
        case tagme = "TAGME"
        case wat = "WAT"
    }
    override func encode(to encoder: Encoder) throws {
        try super.encode(to: encoder)
        var container = encoder.container(keyedBy: NoteCodingKeys.self)
        do {
            try container.encode(documents, forKey: .documents)
            try container.encode(hiddenDocuments, forKey: .hiddenDocuments)
            log.info("Encoded note documents.")
        } catch {
            log.error("Error while encoding documents of note.")
        }
        try container.encode(tags, forKey: .tags)
        try container.encode(activePageIndex, forKey: .activePageIndex)
        try container.encode(helpLinesType, forKey: .helpLinesType)
        try container.encode(pages, forKey: .pages)
        try container.encode(tagmeEpsilon, forKey: .tagmeEpsilon)
    }
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: NoteCodingKeys.self)
        var docsArrayForType = try container.nestedUnkeyedContainer(forKey: .documents)
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
                case .WAT:
                    docs.append(try docsArray.decode(WATDocument.self))
                case .Other:
                    docs.append(try docsArray.decode(Document.self))
                    break
                }
            }
        } catch {
            log.error("Decoding a note's documents failed.")
            log.error(error)
        }
        documents = docs
        hiddenDocuments = [Document]()
        do {
            var hiddenDocsArrayForType = try container.nestedUnkeyedContainer(forKey: .hiddenDocuments)
            docsArray = hiddenDocsArrayForType
            while(!hiddenDocsArrayForType.isAtEnd) {
                let doc = try hiddenDocsArrayForType.nestedContainer(keyedBy: DocumentTypeKey.self)
                let t = try doc.decode(DocumentType.self, forKey: DocumentTypeKey.type)
                switch t {
                case .Spotlight:
                        hiddenDocuments.append(try docsArray.decode(SpotlightDocument.self))
                        break
                case .BioPortal:
                        hiddenDocuments.append(try docsArray.decode(BioPortalDocument.self))
                        break
                case .Chemistry:
                        hiddenDocuments.append(try docsArray.decode(CHEBIDocument.self))
                        break
                case .TAGME:
                        hiddenDocuments.append(try docsArray.decode(TAGMEDocument.self))
                        break
                case .WAT:
                        hiddenDocuments.append(try docsArray.decode(WATDocument.self))
                        break
                case .Other:
                        hiddenDocuments.append(try docsArray.decode(Document.self))
                        break
                }
            }
        } catch {
            log.error("Decoding a note's hidden documents failed.")
            log.error(error)
        }
        
        tags = (try? container.decode([Tag].self, forKey: .tags)) ?? [Tag]()
        activePageIndex = try container.decode(Int.self, forKey: .activePageIndex)
        helpLinesType = (try? container.decode(HelpLinesType.self, forKey: .helpLinesType)) ?? .None
        pages = try container.decode([NotePage].self, forKey: .pages)
        tagmeEpsilon = (try? container.decode(Float.self, forKey: .tagmeEpsilon)) ?? 0.3
        try super.init(from: decoder)
        for doc in documents {
            doc.delegate = self
        }
        log.info("Note " + self.getName() + " decoded.")
    }
    
    public func duplicate() -> Note {
        let documents = self.documents
        let duplicate = Note(name: self.getName(), parent: self.parent, documents: documents)
        duplicate.setName(name: self.getName() + " #2")
        duplicate.tags = self.tags
        return duplicate
    }
    
    //MARK: updating data
    func hide(document: Document) {
        if (!isHidden(document: document)) {
            hiddenDocuments.append(document)
        }
        removeDocument(document: document)
    }
    
    func isHidden(document: Document) -> Bool {
        if hiddenDocuments.contains(document) {
            return true
        }
        return false
    }
    
    func unhide(document: Document) {
        if isHidden(document: document) {
            hiddenDocuments.removeAll{$0 == document}
        }
        self.addDocument(document: document)
    }
    
    public func clear() {
        documents = [Document]()
    }
    
    func addDocument(document: Document) {
        if !documents.contains(document) && isDocumentValid(document: document) {
            documents.append(document)
            document.delegate = self
            self.delegate?.noteHasNewDocument(note: self, document: document)
            DataManager.save(file: self)
        }
    }
    
    private func isDocumentValid(document: Document) -> Bool {
        if isHidden(document: document) {
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
        return true
    }
    
    func removeDocument(document: Document) {
        if documents.contains(document) {
            documents.removeAll{$0 == document}
            self.delegate?.noteHasRemovedDocument(note: self, document: document)
        }
    }
    
    func clearDocuments() {
        self.documents = [Document]()
    }
    
    func setDocumentPreviewImage(document: Document, image: UIImage) {
        if self.documents.contains(document) {
            self.delegate?.noteDocumentHasChanged(note: self, document: document)
        }
    }
    func setDocumentMapImage(document: Document, image: UIImage) {
        if self.documents.contains(document) {
            if document is TAGMEDocument {
                (document as! TAGMEDocument).mapImage = image
                self.delegate?.noteDocumentHasChanged(note: self, document: document)
            }
            else if document is SpotlightDocument {
                (document as! SpotlightDocument).mapImage = image
                self.delegate?.noteDocumentHasChanged(note: self, document: document)
            }
        }
    }
    func setDocumentMoleculeImage(document: CHEBIDocument, image: UIImage) {
        if self.documents.contains(document) {
            document.moleculeImage = image
            self.delegate?.noteDocumentHasChanged(note: self, document: document)
        }
    }
    
    func documentHasChanged(document: Document) {
        self.delegate?.noteDocumentHasChanged(note: self, document: document)
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
                if (self.getName().lowercased().contains(filter.term) || self.getText().lowercased().contains(filter.term)) {
                    matches += 1
                    isInText = true
                }
                var isInDrawings = false
                for page in pages {
                    if page.drawingLabels.contains(filter.term) {
                        matches += 1
                        isInDrawings = true
                        break
                    }
                }
                if !isInText && !isInDrawings {
                    currentSearchFilter = filter
                    for doc in documents {
                        doc.accept(visitor: self)
                        if matchesSearch {
                            matches += 1
                            break
                        }
                    }
                }
                break
            case .Text:
                if (self.getName().lowercased().contains(filter.term) || self.getText().lowercased().contains(filter.term)) {
                    matches += 1
                }
                break
            case .Drawing:
                for page in pages {
                    if page.drawingLabels.contains(filter.term) {
                        matches += 1
                        break
                    }
                }
                break
            case .Document:
                currentSearchFilter = filter
                for doc in documents {
                    doc.accept(visitor: self)
                    if matchesSearch {
                        matches += 1
                        break
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
    
    func process(document: WATDocument) {
        if !processBaseDocumentSearch(document: document) {
            if let spot = document.spot {
                if spot.lowercased().contains(currentSearchFilter!.term) {
                    matchesSearch = true
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
        if pages.count > 0 {
            let pdfWidth = UIScreen.main.bounds.width
            let pdfHeight = UIScreen.main.bounds.height
            
            let bounds = CGRect(x: 0, y: 0, width: pdfWidth, height: pdfHeight)
            let mutableData = NSMutableData()
            UIGraphicsBeginPDFContextToData(mutableData, bounds, nil)
            for page in pages {
                UIGraphicsBeginPDFPage()
                    
                var yOrigin: CGFloat = 0
                while yOrigin < bounds.maxY {
                    let imgBounds = CGRect(x: 0, y: yOrigin, width: pdfWidth, height: pdfHeight)
                    UITraitCollection(userInterfaceStyle: .light).performAsCurrent {
                        var image = page.canvasDrawing.image(from: imgBounds, scale: 2)
                        if let pdfDocument = page.getPDFDocument() {
                            if let page = pdfDocument.page(at: 0) {
                                let pdfImage = page.thumbnail(of: bounds.size, for: .mediaBox)
                                image = pdfImage.mergeWith(withImage: image)
                            }
                        }
                        image.draw(in: imgBounds)
                        yOrigin += pdfHeight
                    }
                }
            }
            UIGraphicsEndPDFContext()
            return mutableData as Data
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
    
    override public func getPreviewImage(completion: @escaping (UIImage) -> Void) {
        if pages.count > 0 {
            UITraitCollection(userInterfaceStyle: .light).performAsCurrent {
                pages[0].getAsImage(completion: {image in
                    completion(image)
                })
            }
        }
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
    
    public func deletePage(index: Int) -> Bool {
        if pages.count > 1 {
            if index >= 0 && index < pages.count {
                pages.remove(at: index)
                if activePageIndex == index {
                    activePageIndex -= 1
                }
                return true
            }
            return false
        }
        return false
    }
    
    func removePage(at indexPath: IndexPath) {
      pages.remove(at: indexPath.row)
    }
      
    func insertPage(_ notePage: NotePage, at indexPath: IndexPath) {
      pages.insert(notePage, at: indexPath.row)
    }
    
    public func mergeWith(note: Note) {
        if note != self {
            for page in note.pages {
                self.pages.append(page)
            }
            self.mergeTagsWith(note: note)
            self.setUpdateDate()
        }
    }
    
    public func mergeTagsWith(note: Note) {
        for tag in note.tags {
            if !self.tags.contains(tag) {
                self.tags.append(tag)
            }
        }
    }
    
    public func getDocuments(forCurrentPage: Bool = false) -> [Document] {
        if forCurrentPage {
            var docs = [Document]()
            for doc in documents {
                var documentTitle = doc.title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                if let TAGMEDocument = doc as? TAGMEDocument {
                    if let spot = TAGMEDocument.spot {
                        documentTitle = spot.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                    }
                }
                else if let watDocument = doc as? WATDocument {
                    if let spot = watDocument.spot {
                        documentTitle = spot.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                    }
                }
                if self.getCurrentPage().getText().lowercased().contains(documentTitle) && !docs.contains(doc) {
                    docs.append(doc)
                }
            }
            return docs
        }
        return self.documents
    }
}

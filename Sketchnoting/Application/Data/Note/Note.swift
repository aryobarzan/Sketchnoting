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

enum NoteTextViewOption: String {
    case FullText
    case HandwrittenText
    case PDFText
}

protocol NoteDelegate {
    func noteHasNewDocument(note: Note, document: Document)
    func noteHasRemovedDocument(note: Note, document: Document)
    func noteDocumentHasChanged(note: Note, document: Document)
    func noteHasChanged(note: Note)
}

class Note: File, DocumentDelegate {
    private var id: String
    var pages: [NotePage]
    private var documents: [Document]
    var activePageIndex = 0
    var helpLinesType: HelpLinesType
    var tagmeEpsilon: Float = 0.3
    
    var sharedByDevice: String?
    
    var delegate: NoteDelegate?
    
    init(name: String, documents: [Document]?) {
        self.id = UUID.init().uuidString
        self.documents = documents ?? [Document]()
        self.pages = [NotePage]()
        self.helpLinesType = .None
        let firstPage = NotePage()
        self.pages.append(firstPage)
        super.init(name: name)
    }
    
    //Codable
    enum NoteCodingKeys: String, CodingKey {
        case id = "id"
        case documents = "documents"
        case activePageIndex
        case helpLinesType = "helpLinesType"
        case pages = "pages"
        case tagmeEpsilon = "tagmeEpsilon"
    }
    private enum DocumentTypeKey : String, CodingKey {
        case type = "DocumentType"
    }
    private enum DocumentTypes : String, Decodable {
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
        } catch {
            logger.error("Error while encoding documents of note.")
        }
        try container.encode(id, forKey: .id)
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
                    break
                case .ALMAAR:
                    docs.append(try docsArray.decode(ARDocument.self))
                    break
                case .Other:
                    docs.append(try docsArray.decode(Document.self))
                    break
                }
            }
        } catch {
            logger.error("Decoding a note's documents failed: \(error)")
        }
        documents = docs
        
        id = (try? container.decode(String.self, forKey: .id)) ?? UUID.init().uuidString
        activePageIndex = try container.decode(Int.self, forKey: .activePageIndex)
        helpLinesType = (try? container.decode(HelpLinesType.self, forKey: .helpLinesType)) ?? .None
        pages = try container.decode([NotePage].self, forKey: .pages)
        tagmeEpsilon = (try? container.decode(Float.self, forKey: .tagmeEpsilon)) ?? 0.3
        try super.init(from: decoder)
        for doc in documents {
            doc.delegate = self
        }
    }
    
    public func getID() -> String {
        return id
    }
    
    public func getDrawingLabels() -> [String] {
        var labels = [String]()
        for page in pages {
            labels += page.getDrawingLabels()
        }
        return Array(Set(labels))
    }
    
    //MARK: updating data
    func add(pages: [NotePage]) {
        var i = activePageIndex + 1
        for p in pages {
            self.pages.insert(p, at: i)
            i += 1
        }
    }
    
    func add(page: NotePage) {
        self.pages.insert(page, at: activePageIndex + 1)
    }
    
    func insert(page: NotePage, i: Int) {
        if self.pages.count == 0 {
            self.pages.append(page)
        }
        else {
            if i <= self.pages.count && i >= 0 {
                self.pages.insert(page, at: i)
            }
        }
    }
    
    
    func hide(document: Document) {
        document.isHidden = true
    }
    
    func isHidden(document: Document) -> Bool {
        return document.isHidden
    }
    
    func unhide(document: Document) {
        document.isHidden = false
    }
    
    public func clear() {
        documents = [Document]()
    }
    
    func addDocument(document: Document) {
        if !documents.contains(document) && isDocumentValid(document: document) {
            documents.append(document)
            document.delegate = self
            self.delegate?.noteHasNewDocument(note: self, document: document)
        }
    }
    
    private func isDocumentValid(document: Document) -> Bool {
        if isHidden(document: document) {
            return false
        }
        if let doc = document as? BioPortalDocument {
            let blacklistedBioPortalTerms = ["place", "city", "populated", "country", "capital", "location", "state", "town"]
            for term in blacklistedBioPortalTerms {
                if let description = doc.getDescription() {
                    if description.lowercased().contains(term) {
                        return false
                    }
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
            self.delegate?.noteDocumentHasChanged(note: self, document: document)
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
    
    public func getText(option: NoteTextViewOption = .FullText, parse: Bool = false) -> String {
        var text: String = ""
        for page in pages {
            text = text + page.getText(option: option, parse: parse)
            text += "\n"
        }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    // MARK: PDF Generation
    
    func createPDF(completion: @escaping (Data?) -> Void) {
        UITraitCollection(userInterfaceStyle: .light).performAsCurrent {
            if pages.count > 0 {
                let pdfWidth = UIScreen.main.bounds.width
                let pdfHeight = UIScreen.main.bounds.height
                
                let bounds = CGRect(x: 0, y: 0, width: pdfWidth, height: pdfHeight)
                let mutableData = NSMutableData()
                UIGraphicsBeginPDFContextToData(mutableData, bounds, nil)
                for page in pages {
                    UIGraphicsBeginPDFPage()
                    var image = page.canvasDrawing.image(from: bounds, scale: 1.0)
                    let canvasImage = image
                    var pdfImage: UIImage?
                    if let pdfDocument = page.getPDFDocument() {
                        if let p = pdfDocument.page(at: 0) {
                            pdfImage = p.thumbnail(of: p.bounds(for: .cropBox).size, for: .cropBox)
                        }
                    }
                    if let pdfImage = pdfImage {
                        image = pdfImage.mergeAlternatively(with: canvasImage)
                    }
                    for layer in page.getLayers(type: .Image) {
                        if let noteImage = layer as? NoteImage {
                            image = image.add(image: noteImage)
                        }
                    }
                    for layer in page.getLayers(type: .TypedText) {
                        if let noteTypedText = layer as? NoteTypedText {
                            image = image.addText(drawText: noteTypedText)
                        }
                    }
                    image.draw(in: bounds)
                }
                UIGraphicsEndPDFContext()
                completion(mutableData as Data)
            }
            else {
                completion(nil)
            }
        }
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
        }
    }
    
    public func getDocuments(forCurrentPage: Bool = false, includeHidden: Bool = false) -> [Document] {
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
                if self.getCurrentPage().getRecognizedText().getText().lowercased().contains(documentTitle) && !docs.contains(doc) {
                    if doc.isHidden {
                        if includeHidden {
                            docs.append(doc)
                        }
                    }
                    else {
                        docs.append(doc)
                    }
                }
            }
            return docs
        }
        if includeHidden {
            return self.documents
        }
        else {
            return self.documents.filter { doc in
                if !doc.isHidden {
                    return true
                }
                return false
            }
        }
    }
    
    public func getDocuments(forPage: NotePage, includeHidden: Bool = false) -> [Document] {
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
            if forPage.getText().lowercased().contains(documentTitle) && !docs.contains(doc) {
                docs.append(doc)
            }
        }
        if includeHidden {
            return documents
        }
        else {
            return docs.filter { doc in
                if !doc.isHidden {
                    return true
                }
                return false
            }
        }
    }
}

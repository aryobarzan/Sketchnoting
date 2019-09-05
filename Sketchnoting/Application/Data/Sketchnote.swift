//
//  Sketchnote.swift
//  Sketchnoting
//
//  Created by Aryobarzan on 26/02/2019.
//  Copyright © 2019 Aryobarzan. All rights reserved.
//

import UIKit

protocol SketchnoteDelegate {
    func sketchnoteHasNewDocument(sketchnote: Sketchnote, document: Document)
    func sketchnoteHasRemovedDocument(sketchnote: Sketchnote, document: Document)
    func sketchnoteDocumentHasChanged(sketchnote: Sketchnote, document: Document)
    func sketchnoteHasChanged(sketchnote: Sketchnote)
}

class Sketchnote: Note, Equatable, DocumentVisitor, Comparable {
    
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
    }
    
    //MARK: Persistence
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(creationDate.timeIntervalSince1970, forKey: .creationDate)
        try container.encode(updateDate?.timeIntervalSince1970, forKey: .updateDate)
        print("Encoding documents.")
        do {
            try container.encode(documents, forKey: .relatedDocuments)
            print("Documents encoded.")
        } catch {
            print("Document encoding failed.")
        }
        
        try container.encode(drawings, forKey: .drawings)
        try container.encode(drawingViewRects, forKey: .drawingViewRects)
        if image != nil {
            let imageData: Data = image!.pngData()!
            let strBase64 = imageData.base64EncodedString(options: .lineLength64Characters)
            try container.encode(strBase64, forKey: .image)
        }
    }
    
    required init(from decoder: Decoder) throws {
        print("Decoding sketchnote.")
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
            print(docs.count)
        }
        } catch {
            print(error)
        }
        self.documents = docs
        
        drawings = try? container.decode([String].self, forKey: .drawings)
        drawingViewRects = try? container.decode([CGRect].self, forKey: .drawingViewRects)
        do {
            let strBase64: String = try container.decode(String.self, forKey: .image)
            let dataDecoded: Data = Data(base64Encoded: strBase64, options: .ignoreUnknownCharacters)!
            image = UIImage(data: dataDecoded)
        } catch {
        }
        
        self.loadPaths()
        self.loadTextDataArray()
        print("Sketchnote decoded")
        print("Sketchnote has \(documents?.count ?? -1) documents.")
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
            print("Note " + id + " saved.")
            if self.paths != nil {
                self.savePaths()
            }
            self.saveTextDataArray()
        }
        else {
            print("Encoding failed for note " + id + ".")
        }
    }
    private func savePaths() {
        let DocumentsDirectory = FileManager().urls(for: .documentDirectory, in: .userDomainMask).first!
        let ArchiveURLPathArray = DocumentsDirectory.appendingPathComponent("NotePaths-" + self.id)
        if let encoded = try? NSKeyedArchiver.archivedData(withRootObject: self.paths, requiringSecureCoding: false) {
            try! encoded.write(to: ArchiveURLPathArray)
            print("Note " + id + " paths saved.")
        }
        else {
            print("Failed to encode paths for note " + id + ".")
        }
    }
    private func loadPaths() {
        let DocumentsDirectory = FileManager().urls(for: .documentDirectory, in: .userDomainMask).first!
        let ArchiveURLPathArray = DocumentsDirectory.appendingPathComponent("NotePaths-" + self.id)
        guard let codedData = try? Data(contentsOf: ArchiveURLPathArray) else { return }
        guard let data = ((try? NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(codedData) as?
            NSMutableArray) as NSMutableArray??) else { return }
        print("Paths for note " + id + " loaded.")
        self.paths = data
    }
    private func saveTextDataArray() {
        let DocumentsDirectory = FileManager().urls(for: .documentDirectory, in: .userDomainMask).first!
        let ArchiveURLPathArray = DocumentsDirectory.appendingPathComponent("NoteTextDataArray-" + self.id)
        if let encoded = try? NSKeyedArchiver.archivedData(withRootObject: self.textDataArray, requiringSecureCoding: false) {
            try! encoded.write(to: ArchiveURLPathArray)
            print("Note " + id + " text data array saved.")
        }
        else {
            print("Failed to encode text data array for note " + id + ".")
        }
    }
    private func loadTextDataArray() {
        let DocumentsDirectory = FileManager().urls(for: .documentDirectory, in: .userDomainMask).first!
        let ArchiveURLPathArray = DocumentsDirectory.appendingPathComponent("NoteTextDataArray-" + self.id)
        guard let codedData = try? Data(contentsOf: ArchiveURLPathArray) else { return }
        guard let data = ((try? NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(codedData) as?
            [TextData]) as [TextData]??) else { return }
        print("Text data array for note " + id + " loaded.")
        self.textDataArray = data
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
    var currentSearchFilter : String?
    public func applySearchFilters(filters: [String]) -> Bool {
        matchesSearch = false
        for filter in filters {
            if (self.title.lowercased().contains(filter) || self.getText().lowercased().contains(filter)) || (self.drawings?.contains(filter) ?? false) {
                return true
            }
            else {
                currentSearchFilter = filter
                if let documents = self.documents {
                    for doc in documents {
                        doc.accept(visitor: self)
                        if matchesSearch {
                            return true
                        }
                    }
                }
            }
        }
        return false
    }
    func process(document: Document) {
        let _ = self.processBaseDocumentSearch(document: document)
    }
    
    func process(document: SpotlightDocument) {
        if !processBaseDocumentSearch(document: document) {
            if let label = document.label {
                if label.lowercased().contains(currentSearchFilter!) {
                    matchesSearch = true
                }
            }
            if let types = document.types {
                for type in types {
                    if type.lowercased().contains(currentSearchFilter!) {
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
                if spot.lowercased().contains(currentSearchFilter!) {
                    matchesSearch = true
                }
            }
            if let categories = document.categories {
                for category in categories {
                    if category.lowercased().contains(currentSearchFilter!) {
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
        if document.title.lowercased().contains(currentSearchFilter!) {
            matchesSearch = true
            return true
        }
        else if let description = document.description {
            if description.lowercased().contains(currentSearchFilter!) {
                matchesSearch = true
                return true
            }
        }
        return false
    }

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

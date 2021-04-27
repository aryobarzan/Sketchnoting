//
//  SKGraphSearch.swift
//  Sketchnoting
//
//  Created by Aryobarzan on 26/04/2021.
//  Copyright © 2021 Aryobarzan. All rights reserved.
//

import Foundation
import NaturalLanguage
import SwiftGraph

class SKGraphSearch {
    static public var shared = SKGraphSearch()
    
    private init() {}
    
    var graph: WeightedGraph<GraphVertex, Double>!
    var noteVertexIdx = [Int : Int]()
    var documentVertexIdx = [Int : Int]()
    var drawingVertexIdx = [Int : Int]()
    
    func setup() {
        var noteIterator = NeoLibrary.getNoteIterator()
        graph = WeightedGraph<GraphVertex, Double>()
        while let note = noteIterator.next() {
            let noteIdx = graph.addVertex(GraphNoteVertex(url: note.0, note: note.1))
            noteVertexIdx[note.1.hashValue] = noteIdx
            for document in note.1.getDocuments() {
                if documentVertexIdx[document.hashValue] == nil {
                    let documentIdx = graph.addVertex(GraphDocumentVertex(document: document))
                    documentVertexIdx[document.hashValue] = documentIdx
                }
                graph.addEdge(WeightedEdge(u: documentVertexIdx[document.hashValue]!, v: noteIdx, directed: true, weight: 1.0), directed: false)
            }
            for drawing in note.1.getDrawingLabels() {
                if drawingVertexIdx[drawing.hashValue] == nil {
                    let drawingIdx = graph.addVertex(GraphDrawingVertex(drawing: drawing))
                    drawingVertexIdx[drawing.hashValue] = drawingIdx
                }
                graph.addEdge(WeightedEdge(u: drawingVertexIdx[drawing.hashValue]!, v: noteIdx, directed: true, weight: 1.0), directed: false)
            }
        }
    }
    
    func getDocuments(filterOptions: [ExploreSearchDocumentOption] = [ExploreSearchDocumentOption]()) -> [Document] {
        if filterOptions.isEmpty {
            return graph.vertices.filter {$0.type == .Document}.map{($0 as! GraphDocumentVertex).document}.sorted{doc1, doc2 in doc1.title < doc2.title}
        }
        else {
            var documents = [Int : Document]()
            for (_, noteVertexId) in noteVertexIdx {
                let edges = graph.edgesForIndex(noteVertexId)
                var matchCount = 0
                for filterDocument in filterOptions {
                    for edge in edges {
                        if let documentVertex = graph.vertexAtIndex(edge.v) as? GraphDocumentVertex {
                            if documentVertex.document == filterDocument.document {
                                matchCount += 1
                            }
                        }
                    }
                }
                if matchCount == filterOptions.count {
                    edges.map{(graph.vertexAtIndex($0.v) as! GraphDocumentVertex).document}.forEach {foundDocument in
                        documents[foundDocument.hashValue] = foundDocument
                    }
                }
            }
            return documents.map{$0.value}.sorted{doc1, doc2 in doc1.title < doc2.title}
        }
    }
}

class GraphVertex: Codable, Equatable {
    let type: GraphVertexType
    
    init(type: GraphVertexType) {
        self.type = type
    }
    
    private enum CodingKeys: String, CodingKey {
        case type = "Type"
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type, forKey: .type)
    }
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        type = try container.decode(GraphVertexType.self, forKey: CodingKeys.type)
    }
    
    static func == (lhs: GraphVertex, rhs: GraphVertex) -> Bool {
        return lhs.type == rhs.type
    }
}

enum GraphVertexType: String, Codable {
    case Note = "Note"
    case Document = "Document"
    case Drawing = "Drawing"
}

class GraphNoteVertex: GraphVertex {
    let url: URL
    let note: Note
    
    init(url: URL, note: Note) {
        self.url = url
        self.note = note
        super.init(type: .Note)
    }
    
    private enum CodingKeys: String, CodingKey {
        case note = "Note"
        case url = "URL"
    }
    
    override func encode(to encoder: Encoder) throws {
        try super.encode(to: encoder)
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(url, forKey: .url)
        try container.encode(note, forKey: .note)
    }
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        url = try container.decode(URL.self, forKey: .url)
        note = try container.decode(Note.self, forKey: .note)
        try super.init(from: decoder)
    }
}

class GraphDocumentVertex: GraphVertex {
    let document: Document
    
    init(document: Document) {
        self.document = document
        super.init(type: .Document)
    }
    
    private enum CodingKeys: String, CodingKey {
        case document = "Document"
    }
    
    override func encode(to encoder: Encoder) throws {
        try super.encode(to: encoder)
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(document, forKey: .document)
    }
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        document = try container.decode(Document.self, forKey: .document)
        try super.init(from: decoder)
    }
}

class GraphDrawingVertex: GraphVertex {
    let drawing: String
    
    init(drawing: String) {
        self.drawing = drawing
        super.init(type: .Drawing)
    }
    
    private enum CodingKeys: String, CodingKey {
        case drawing = "Drawing"
    }
    
    override func encode(to encoder: Encoder) throws {
        try super.encode(to: encoder)
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(drawing, forKey: .drawing)
    }
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        drawing = try container.decode(String.self, forKey: .drawing)
        try super.init(from: decoder)
    }
}

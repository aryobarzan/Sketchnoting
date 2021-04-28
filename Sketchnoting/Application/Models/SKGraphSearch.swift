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
    
    private var graph: WeightedGraph<GraphVertex, Double>!
    private var activeGraph: WeightedGraph<GraphVertex, Double>!
    
    func setup() {
        var noteIterator = NeoLibrary.getNoteIterator()
        graph = WeightedGraph<GraphVertex, Double>()
        var documentVertexIdx = [Int : Int]()
        var drawingVertexIdx = [Int : Int]()
        while let note = noteIterator.next() {
            let noteIdx = graph.addVertex(GraphNoteVertex(url: note.0, note: note.1))
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
        resetActiveGraph()
    }
    
    func resetActiveGraph() {
        activeGraph = graph
    }
    
    func getTimeframeOptions() -> [ExploreSearchTimeframeOption] {
        var recentCount = 0
        var olderCount = 0
        for vertex in activeGraph.vertices {
            if vertex.type == .Note, let noteVertex = vertex as? GraphNoteVertex {
                if isNoteRecent(url: noteVertex.url) {
                    recentCount += 1
                }
                else {
                    olderCount += 1
                }
            }
        }
        var options = [ExploreSearchTimeframeOption]()
        if recentCount > 0 && olderCount > 0 {
            if recentCount > olderCount {
                options.append(ExploreSearchTimeframeOption(timeframe: .Recent))
                options.append(ExploreSearchTimeframeOption(timeframe: .Older))
            }
            else {
                options.append(ExploreSearchTimeframeOption(timeframe: .Older))
                options.append(ExploreSearchTimeframeOption(timeframe: .Recent))
            }
        }
        else {
            if recentCount > 0 {
                options.append(ExploreSearchTimeframeOption(timeframe: .Recent))
            }
            else if olderCount > 0 {
                options.append(ExploreSearchTimeframeOption(timeframe: .Older))
            }
        }
        return options
    }
    
    private func isNoteRecent(url: URL) -> Bool {
        let modificationDate = NeoLibrary.getModificationDate(url: url)
        let currentDate = Date()
        let daysDifference = abs(currentDate.fullDistance(from: modificationDate, resultIn: .day) ?? 0)
        if daysDifference <= 7 {
            return true
        }
        else {
            return false
        }
    }
    
    func applyTimeframe(option: ExploreSearchTimeframeOption) {
        var toRemove = [Int]()
        for (vertexIdx, vertex) in activeGraph.vertices.enumerated() {
            if let noteVertex = vertex as? GraphNoteVertex {
                let isRecent = isNoteRecent(url: noteVertex.url)
                switch option.timeframe {
                case .Recent:
                    if !isRecent {
                        toRemove.append(vertexIdx)
                    }
                    break
                case .Older:
                    if isRecent {
                        toRemove.append(vertexIdx)
                    }
                    break
                }
            }
        }
        toRemove.sorted(by: >).forEach { rmIndex in activeGraph.removeVertexAtIndex(rmIndex)}
    }
    
    func getLengthOptions(timeframeOption: ExploreSearchTimeframeOption? = nil) -> [ExploreSearchLengthOption] {
        var shortCount = 0
        var longCount = 0
        for vertex in activeGraph.vertices {
            if vertex.type == .Note, let noteVertex = vertex as? GraphNoteVertex {
                let isShort = isNoteShort(note: noteVertex.note)
                if isShort {
                    shortCount += 1
                }
                else {
                    longCount += 1
                }
            }
        }
        var options = [ExploreSearchLengthOption]()
        if shortCount > 0 && longCount > 0 {
            if shortCount > longCount {
                options.append(ExploreSearchLengthOption(length: .Short))
                options.append(ExploreSearchLengthOption(length: .Long))
            }
            else {
                options.append(ExploreSearchLengthOption(length: .Long))
                options.append(ExploreSearchLengthOption(length: .Short))
            }
        }
        else {
            if shortCount > 0 {
                options.append(ExploreSearchLengthOption(length: .Short))
            }
            else if longCount > 0 {
                options.append(ExploreSearchLengthOption(length: .Long))
            }
        }
        return options
    }
    
    private func isNoteShort(note: Note) -> Bool {
        return note.getText(option: .FullText, parse: false).count < 200
    }
    
    func applyLength(option: ExploreSearchLengthOption) {
        var toRemove = [Int]()
        for (vertexIdx, vertex) in activeGraph.vertices.enumerated() {
            if let noteVertex = vertex as? GraphNoteVertex {
                let isShort = isNoteShort(note: noteVertex.note)
                switch option.length {
                case .Short:
                    if !isShort {
                        toRemove.append(vertexIdx)
                    }
                    break
                case .Long:
                    if isShort {
                        toRemove.append(vertexIdx)
                    }
                    break
                }
            }
        }
        toRemove.sorted(by: >).forEach { rmIndex in activeGraph.removeVertexAtIndex(rmIndex)}
    }
    
    func getDocumentOptions(selectedDocumentOptions: [ExploreSearchDocumentOption] = [ExploreSearchDocumentOption]()) -> [ExploreSearchDocumentOption] {
        var documents = [(ExploreSearchDocumentOption, Int)]()
        if selectedDocumentOptions.isEmpty {
            for (vertexIdx, vertex) in activeGraph.vertices.enumerated() {
                if vertex.type == .Document, let documentVertex = vertex as? GraphDocumentVertex {
                    let documentVertexEdges = activeGraph.edgesForIndex(vertexIdx)
                    if documentVertexEdges.count > 0 {
                        documents.append((ExploreSearchDocumentOption(document: documentVertex.document), documentVertexEdges.count))
                    }
                }
            }
        }
        else {
            var documentVertexIdxValid = [Int]()
            for (vertexIdx, vertex) in activeGraph.vertices.enumerated() {
                if vertex.type == .Note {
                    let edges = activeGraph.edgesForIndex(vertexIdx)
                    var matchCount = 0
                    for selectedDocumentOption in selectedDocumentOptions {
                        for edge in edges {
                            if let documentVertex = activeGraph.vertexAtIndex(edge.v) as? GraphDocumentVertex {
                                if documentVertex.document == selectedDocumentOption.document {
                                    matchCount += 1
                                    break
                                }
                            }
                        }
                    }
                    if matchCount == selectedDocumentOptions.count {
                        documentVertexIdxValid += edges.map{$0.v}.filter{activeGraph.vertexAtIndex($0) is GraphDocumentVertex}
                    }
                }
            }
            for documentVertexId in documentVertexIdxValid {
                if let documentVertex = activeGraph.vertexAtIndex(documentVertexId) as? GraphDocumentVertex {
                    let documentVertexEdges = activeGraph.edgesForIndex(documentVertexId)
                    if documentVertexEdges.count > 0 {
                        documents.append((ExploreSearchDocumentOption(document: documentVertex.document), documentVertexEdges.count))
                    }
                }
            }
        }
        documents = documents.sorted{item1, item2 in
            item1.1 > item2.1
            
        }
        return documents.map{$0.0}
    }
}

class GraphVertex: Codable, Equatable, Hashable {
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
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(type)
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
    
    override func hash(into hasher: inout Hasher) {
        hasher.combine(url)
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
    
    override func hash(into hasher: inout Hasher) {
        hasher.combine(document)
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
    
    override func hash(into hasher: inout Hasher) {
        hasher.combine(drawing)
    }
}

//
//  AppSearch.swift
//  Sketchnoting
//
//  Created by Aryobarzan on 10/06/2020.
//  Copyright © 2020 Aryobarzan. All rights reserved.
//

import UIKit

class AppSearch: DocumentVisitor {
    
    public func search(filters: [SearchFilter]) -> [Note] {
        var results = [Note]()
        if filters.count > 0 {
            results = DataManager.notes
            var searchedNotesToRemove = [Note]()
            for note in results {
                if !applySearchFilters(note: note, filters: filters) {
                        searchedNotesToRemove.append(note)
                }
            }
            results = results.filter { !searchedNotesToRemove.contains($0) }
        }
        return results
    }
    
    private func applySearchFilters(note: Note, filters: [SearchFilter]) -> Bool {
        var matchingFiltersCount = 0
        for filter in filters {
            switch (filter.type) {
            case .All:
                if self.applyTextFilter(note: note, term: filter.term) ||
                    self.applyDrawingFilter(note: note, term: filter.term) ||
                    self.applyDocumentFilter(note: note, term: filter.term) {
                    matchingFiltersCount += 1
                }
            case .Text:
                if self.applyTextFilter(note: note, term: filter.term) {
                    matchingFiltersCount += 1
                }
                break
            case .Drawing:
                if self.applyDrawingFilter(note: note, term: filter.term) {
                    matchingFiltersCount += 1
                }
                break
            case .Document:
                 if self.applyDocumentFilter(note: note, term: filter.term) {
                    matchingFiltersCount += 1
                }
                break
            }
        }
        if matchingFiltersCount == filters.count {
            return true
        }
        return false
    }
    
    private func applyTextFilter(note: Note, term: String) -> Bool {
        if note.getName().lowercased().contains(term) || note.getText().lowercased().contains(term) {
            return true
        }
        return false
    }
    private func applyDrawingFilter(note: Note, term: String) -> Bool {
        for page in note.pages {
            for drawing in page.getDrawingLabels() {
                if drawing.lowercased() == term.lowercased() {
                    return true
                }
            }
        }
        return false
    }
    
    
    private func applyDocumentFilter(note: Note, term: String) -> Bool {
        for doc in note.getDocuments() {
            documentFilterMatches = false
            documentFilterTerm = term
            doc.accept(visitor: self)
            if documentFilterMatches {
                return true
            }
        }
        return false
    }
    private var documentFilterMatches = false
    private var documentFilterTerm = ""
    
    func process(document: Document) {
        let _ = self.processBaseDocumentSearch(document: document)
    }
    
    func process(document: SpotlightDocument) {
        if !processBaseDocumentSearch(document: document) {
            if let label = document.label {
                if label.lowercased().contains(documentFilterTerm) {
                    documentFilterMatches = true
                }
            }
            if let types = document.types {
                for type in types {
                    if type.lowercased().contains(documentFilterTerm) {
                        documentFilterMatches = true
                        break
                    }
                }
            }
        }
    }
    func process(document: TAGMEDocument) {
        if !processBaseDocumentSearch(document: document) {
            if let spot = document.spot {
                if spot.lowercased().contains(documentFilterTerm) {
                    documentFilterMatches = true
                }
            }
            if let categories = document.categories {
                for category in categories {
                    if category.lowercased().contains(documentFilterTerm) {
                        documentFilterMatches = true
                        break
                    }
                }
            }
        }
    }
    
    func process(document: WATDocument) {
        if !processBaseDocumentSearch(document: document) {
            if let spot = document.spot {
                if spot.lowercased().contains(documentFilterTerm) {
                    documentFilterMatches = true
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
        if document.title.lowercased().contains(documentFilterTerm) {
            documentFilterMatches = true
            return true
        }
        else if let description = document.description {
            if description.lowercased().contains(documentFilterTerm) {
                documentFilterMatches = true
                return true
            }
        }
        return false
    }
    
    
    
    // Search within note - Return all pages which match the search filter terms
    public func search(note: Note, filters: [SearchFilter]) -> [Int] {
        var results = [Int]()
        if filters.count > 0 {
            for i in 0..<note.pages.count {
                if applySearchFilters(note: note, page: note.pages[i], filters: filters) {
                    results.append(i)
                }
            }
        }
        return results
    }
    
    private func applySearchFilters(note: Note, page: NotePage, filters: [SearchFilter]) -> Bool {
        var matchingFiltersCount = 0
        for filter in filters {
            switch (filter.type) {
            case .All:
                if self.applyTextFilter(note: note, term: filter.term) ||
                    self.applyDrawingFilter(note: note, term: filter.term) ||
                    self.applyDocumentFilter(note: note, term: filter.term) {
                    matchingFiltersCount += 1
                }
            case .Text:
                if self.applyTextFilter(note: note, term: filter.term) {
                    matchingFiltersCount += 1
                }
                break
            case .Drawing:
                if self.applyDrawingFilter(note: note, term: filter.term) {
                    matchingFiltersCount += 1
                }
                break
            case .Document:
                if self.applyDocumentFilter(documents: note.getDocuments(forPage: page), term: filter.term) {
                    matchingFiltersCount += 1
                }
                break
            }
        }
        if matchingFiltersCount == filters.count {
            return true
        }
        return false
    }
    
    private func applyTextFilter(page: NotePage, term: String) -> Bool {
        if page.getText().lowercased().contains(term) {
            return true
        }
        return false
    }
    private func applyDrawingFilter(page: NotePage, term: String) -> Bool {
        for drawing in page.getDrawingLabels() {
            if drawing.lowercased() == term.lowercased() {
                return true
            }
        }
        return false
    }
    
    
    private func applyDocumentFilter(documents: [Document], term: String) -> Bool {
        for doc in documents {
            documentFilterMatches = false
            documentFilterTerm = term
            doc.accept(visitor: self)
            if documentFilterMatches {
                return true
            }
        }
        return false
    }
}

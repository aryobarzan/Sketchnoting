//
//  Tf-Idf.swift
//  Tf-Idf
//
//  Created by Matteo Piombo on 20/12/15.
//  Copyright © 2015 Matteo Piombo. All rights reserved.
//  https://github.com/perlfly/TF-IDF/blob/master/Tf-Idf/Tf-Idf.swift
//
import Foundation

/// Term Frequency Document Type Protocol
///
/// typealias:
protocol TFDocumentType {
    associatedtype DocumentIDType: Hashable
    associatedtype TermType: Hashable
    
    var documentID: DocumentIDType { get }
}

/// TF-IDF Generic Class
///
/// Will store docuemnt IDs, documents terms freqencies and corpus term count
final class TF_IDF {
    
    typealias TermCount = Dictionary<String, Int>
    
    var documentsTF: Dictionary<String, TermCount>
    var corpusTermCount: TermCount
    
    init() {
        self.documentsTF = [:]
        corpusTermCount = [:]
    }
    
    /// Adds note info to the corpus
    /// Stores note ID, its term frequencies and updates the corpus terms frequencies
    ///
    /// - Parameter document: the document to be added
    ///
    func addNote(note: Note) {
        var tf: TermCount = [:]
        let titleTerms = SemanticSearch.shared.tokenize(text: note.getName(), unit: .word)
        let bodyTerms = SemanticSearch.shared.tokenize(text: note.getText(), unit: .word)
        var terms = titleTerms + bodyTerms
        if let wordEmbedding = SemanticSearch.shared.getWordEmbedding() {
            for i in 0..<terms.count {
                let lemmatized = SemanticSearch.shared.lemmatize(text: terms[i])
                if wordEmbedding.contains(lemmatized) {
                    terms[i] = lemmatized.lowercased()
                }
                else {
                    terms[i] = terms[i].lowercased()
                }
            }
        }
        
        for term in terms {
            if let count = tf[term] {
                tf[term] = count + 1
            } else {
                tf[term] = 1
                corpusTermCount[term] = (corpusTermCount[term] ?? 0) + 1
            }
        }
        documentsTF[note.getID()] = tf
    }
    
    
    /// Removes a document from the corpus
    ///
    /// Updates corpus terms statistics and removes the document's terms frequency
    /// - Parameter document: The document to be removed
    func removeDocument(note: Note) {
        guard let tf = documentsTF[note.getID()] else { return } // return in case the note is not indexed
        // update corpus terms count
        for term in tf.keys {
            guard let corpusCount = corpusTermCount[term] else { return }
            corpusTermCount[term] = (corpusCount > 1) ? corpusCount - 1 : nil

        }
        // Remove document's terms frequency
        documentsTF[note.getID()] = nil
    }
    
    /// Calculates TF-IDF score for each note containing the given term at least one time
    ///
    /// - Parameter term: the term to be used for scoring
    ///
    /// - Returns: Array of tuple (docID, score) where _docID_ is the doc identifier and _score_
    ///     is the doc's score for the given _term_
    func documentsForTerm(term: String) -> [(noteID: String, score: Double)] {
        guard let documentsTermCount = corpusTermCount[term] else {
            return []
        }
        var results: Array<(noteID: String, score: Double)> = []
        let idf = log(Double(documentsTF.count) / Double(documentsTermCount))
        
        for (document, documentTermCount) in documentsTF {
            if let tf = documentTermCount[term] {
                let score = Double(tf) * idf
                results.append((document, score))
            }
        }
        return results
    }
}

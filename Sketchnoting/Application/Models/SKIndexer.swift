//
//  SKIndexer.swift
//  Sketchnoting
//
//  Created by Aryobarzan on 26/03/2021.
//  Copyright © 2021 Aryobarzan. All rights reserved.
//

import UIKit

enum SKIndexerOption {
    case Similarity
    case TFIDF
}

protocol SKIndexerDelegate {
    func skIndexerProgress(remainingOperations: Int)
}

class SKIndexer {
    static var shared = SKIndexer()
    var delegate: SKIndexerDelegate?
    private init(){
        operationQueue.maxConcurrentOperationCount = 1
    }
    
    private let operationQueue = OperationQueue()
    
    func cancelIndexing() {
        operationQueue.cancelAllOperations()
    }
    
    func indexLibrary(_ note: Note? = nil, options: [SKIndexerOption] = [SKIndexerOption.Similarity, SKIndexerOption.TFIDF], finishHandler: ((Bool) -> Void)? = nil) {
        let options = Array(Set(options))
        if let note = note {
            addOperation {
                self.index(note: note, options: options)
            }
        }
        else {
            logger.info("Indexing entire user library.")
            NoteSimilarity.shared.clear()
            var noteIterator = NeoLibrary.getNoteIterator()
            while let note = noteIterator.next() {
                addOperation {
                    self.index(note: note.1, options: options)
                }
            }
        }
        
        addOperation {
            logger.info("Indexing entire library into TF-IDF matrix.")
            NoteSimilarity.shared.setupTFIDF(noteIterator: NeoLibrary.getNoteIterator())
            logger.info("(Indexing) TF-IDF indexing complete.")
        }
        
        operationQueue.addBarrierBlock {
            logger.info("(Indexing) Complete.")
            if let finishHandler = finishHandler {
                finishHandler(true)
            }
        }
    }
    
    private func index(note: Note, options: [SKIndexerOption] = [SKIndexerOption.Similarity, SKIndexerOption.TFIDF]) {
        for option in options {
            switch option {
            case .Similarity:
                NoteSimilarity.shared.add(note: note, uniqueOnly: true, useSentenceEmbedding: true, normalizeVector: true, parse: true, useKeywords: false, useDocuments: false, filterSentences: true)
                break
            case .TFIDF:
                TF_IDF.shared.addNote(note: note)
                break
            }
        }
        logger.info("(Indexing) Note '\(note.getName())' indexed.")
    }
    
    private func addOperation(block: @escaping () -> Void) {
        operationQueue.addOperation {
            block()
            self.delegate?.skIndexerProgress(remainingOperations: self.operationQueue.operationCount - 1)
        }
    }
    
    func isIndexed(note: Note) -> Bool {
        return NoteSimilarity.shared.noteMatrices[note.getID()] != nil
    }
    
    func remove(note: Note) {
        if isIndexed(note: note) {
            NoteSimilarity.shared.remove(note: note)
        }
    }
}

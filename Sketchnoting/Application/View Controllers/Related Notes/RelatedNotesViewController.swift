//
//  RelatedNotesViewController.swift
//  Sketchnoting
//
//  Created by Aryobarzan on 12/05/2020.
//  Copyright © 2020 Aryobarzan. All rights reserved.
//

import UIKit

enum RelatedNotesContext {
    case HomePage
    case NoteEditing
}

protocol RelatedNotesVCDelegate {
    func openRelatedNote(url: URL, note: Note)
}

class RelatedNotesViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout {
    
    private enum SimilarityMethod {
        case TF_IDF
        case Semantic
    }
    
    var note: (URL, Note)!
    var context: RelatedNotesContext = .HomePage
    
    var relatedNotes = [((URL, Note), Double)]()
    private var similarityMethod: SimilarityMethod = .TF_IDF
    var similarityThreshold: Float = 0.5
    
    var openNote: (URL, Note)?
    var delegate: RelatedNotesVCDelegate?

    @IBOutlet weak var countLabel: UILabel!
    @IBOutlet weak var similaritySegmentedControl: UISegmentedControl!
    @IBOutlet weak var collectionView: UICollectionView!
    override func viewDidLoad() {
        super.viewDidLoad()
        
        collectionView.register(UINib(nibName: "NoteCollectionViewCell", bundle: nil), forCellWithReuseIdentifier: "NoteCollectionViewCell")
        collectionView.delegate = self
        collectionView.dataSource = self
        
        self.title = note.1.getName()
        
        refreshRelatedNotes()
    }
    
    @IBAction func doneTapped(_ sender: UIBarButtonItem) {
        self.dismiss(animated: true, completion: nil)
    }
    
    @IBAction func similaritySegmentedControlChanged(_ sender: UISegmentedControl) {
        var newSimilarityMethod: SimilarityMethod
        if sender.selectedSegmentIndex == 0 {
            newSimilarityMethod = .TF_IDF
        }
        else {
            newSimilarityMethod = .Semantic
        }
        if newSimilarityMethod != self.similarityMethod {
            self.similarityMethod = newSimilarityMethod
            self.refreshRelatedNotes()
        }
    }
    
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return relatedNotes.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "NoteCollectionViewCell", for: indexPath as IndexPath) as! NoteCollectionViewCell
        cell.setFile(url: self.relatedNotes[indexPath.item].0.0, file: self.relatedNotes[indexPath.item].0.1, progress: self.relatedNotes[indexPath.item].1)
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        sizeForItemAt indexPath: IndexPath) -> CGSize {
        return CGSize(width: CGFloat(200), height: CGFloat(300))
    }
        
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let related = self.relatedNotes[indexPath.item]
        let alert = UIAlertController(title: "Open Note", message: "Close this note and open the note " + related.0.1.getName() + "?", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Open", style: .default, handler: { action in
            self.dismiss(animated: true, completion: nil)
            self.delegate?.openRelatedNote(url: related.0.0, note: related.0.1)
        }))
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { action in
                logger.info("Not opening note.")
        }))
        self.present(alert, animated: true, completion: nil)
    }
    
    private func refreshRelatedNotes() {
        if similarityMethod == .TF_IDF {
            if !Knowledge.similarityMatrixIsSetup() {
                Knowledge.setupSimilarityMatrix()
            }
            let foundNotes = Knowledge.similarNotesFor(url: note.0, note: note.1)
            self.relatedNotes.removeAll()
            for (url, note, score) in foundNotes {
                if score > 0.1 {
                    self.relatedNotes.append(((url, note), Double(score)))
                }
            }
        }
        else {
            let foundNotes = NoteSimilarity.shared.similarNotes(for: note.1, noteIterator: NeoLibrary.getNoteIterator(), maxResults: 5)
            self.relatedNotes = foundNotes
        }
        collectionView.reloadData()
        countLabel.text = "Related Notes: (\(Int(relatedNotes.count)))"
    }
    @IBAction func refreshButtonTapped(_ sender: UIBarButtonItem) {
        if similarityMethod == .TF_IDF {
            Knowledge.setupSimilarityMatrix()
            logger.info("Refreshed note similarity TF-IDF.")
        }
        else {
            NoteSimilarity.shared.clear()
            var noteIterator = NeoLibrary.getNoteIterator()
            while let note = noteIterator.next() {
                TF_IDF.shared.addNote(note: note.1)
                NoteSimilarity.shared.add(note: note.1)
            }
            logger.info("Refreshed note similarity matrices (semantic).")
        }
        self.refreshRelatedNotes()
    }
}

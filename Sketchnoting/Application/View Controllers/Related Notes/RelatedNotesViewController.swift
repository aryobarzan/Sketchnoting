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
    
    var note: (URL, Note)!
    var context: RelatedNotesContext = .HomePage
    
    var relatedNotes = [((URL, Note), Double)]()
    var similarityThreshold: Float = 0.5
    
    var openNote: (URL, Note)?
    var delegate: RelatedNotesVCDelegate?

    @IBOutlet weak var countLabel: UILabel!
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
        let foundNotes = NoteSimilarity.shared.similarNotes(for: note.1, noteIterator: NeoLibrary.getNoteIterator(), maxResults: 5, similarityMethod: .SemanticMatrix)
        self.relatedNotes = foundNotes
        
        collectionView.reloadData()
        countLabel.text = "Related Notes: (\(Int(relatedNotes.count)))"
    }
}

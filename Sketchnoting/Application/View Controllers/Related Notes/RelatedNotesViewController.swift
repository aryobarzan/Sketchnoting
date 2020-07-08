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

class RelatedNotesViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegate {
    
    private enum SimilarityLevel: Float {
        case Low = 0.1
        case Medium = 0.5
        case High = 0.9
    }
    
    var note: (URL, Note)!
    var context: RelatedNotesContext! = .HomePage
    
    var relatedNotes = [(URL, Note)]()
    var similarityThreshold: Float = 0.5
    private var similarityLevel: SimilarityLevel = .Low
    
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
        var newLevel = self.similarityLevel
        switch sender.titleForSegment(at: sender.selectedSegmentIndex) {
        case "Low":
            newLevel = .Low
            break
        case "Medium":
            newLevel = .Medium
            break
        case "High":
            newLevel = .High
            break
        default:
            break
        }
        if newLevel != self.similarityLevel {
            self.refreshRelatedNotes()
        }
    }
    
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return relatedNotes.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "NoteCollectionViewCell", for: indexPath as IndexPath) as! NoteCollectionViewCell
        cell.setFile(url: self.relatedNotes[indexPath.item].0, file: self.relatedNotes[indexPath.item].1)
        return cell
    }
        
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let related = self.relatedNotes[indexPath.item]
        let alert = UIAlertController(title: "Open Note", message: "Close this note and open the note " + related.1.getName() + "?", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Open", style: .default, handler: { action in
            self.dismiss(animated: true, completion: nil)
            self.delegate?.openRelatedNote(url: related.0, note: related.1)
        }))
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { action in
                log.info("Not opening note.")
        }))
        self.present(alert, animated: true, completion: nil)
    }
    
    private func refreshRelatedNotes() {
        Knowledge.setupSimilarityMatrix()
        let foundNotes = Knowledge.similarNotesFor(url: note.0, note: note.1)
        self.relatedNotes = [(URL, Note)]()
        for (url, note, score) in foundNotes {
            if score > self.similarityLevel.rawValue {
                self.relatedNotes.append((url, note))
            }
        }
        collectionView.reloadData()
        countLabel.text = "Related Notes: (\(relatedNotes.count))"
    }
}

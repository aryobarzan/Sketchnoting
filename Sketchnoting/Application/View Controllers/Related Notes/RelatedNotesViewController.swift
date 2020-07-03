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
    func openRelatedNote(note: Note)
    func mergedNotes(note1: Note, note2: Note)
}

class RelatedNotesViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegate {
    
    private enum SimilarityLevel: Float {
        case Low = 0.1
        case Medium = 0.5
        case High = 0.9
    }
    
    var note: Note!
    var context: RelatedNotesContext! = .HomePage
    
    var relatedNotes = [Note]()
    var similarityThreshold: Float = 0.5
    private var similarityLevel: SimilarityLevel = .Low
    
    var openNote: Note?
    var delegate: RelatedNotesVCDelegate?

    @IBOutlet weak var countLabel: UILabel!
    @IBOutlet weak var similaritySegmentedControl: UISegmentedControl!
    @IBOutlet weak var collectionView: UICollectionView!
    override func viewDidLoad() {
        super.viewDidLoad()
        
        collectionView.register(UINib(nibName: "NoteCollectionViewCell", bundle: nil), forCellWithReuseIdentifier: "NoteCollectionViewCell")
        collectionView.delegate = self
        collectionView.dataSource = self
        
        self.title = note.getName()
        
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
        cell.setFile(file: self.relatedNotes[indexPath.item])
        return cell
    }
        
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let related = self.relatedNotes[indexPath.item]
        let alert = UIAlertController(title: "Open Note", message: "Close this note and open the note " + related.getName() + "?", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Open", style: .default, handler: { action in
            self.dismiss(animated: true, completion: nil)
            self.delegate?.openRelatedNote(note: related)
        }))
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { action in
                log.info("Not opening note.")
        }))
        self.present(alert, animated: true, completion: nil)
    }
    
    func collectionView(_ collectionView: UICollectionView, contextMenuConfigurationForItemAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
        return UIContextMenuConfiguration(identifier: nil, previewProvider: nil, actionProvider: { suggestedActions in

            return self.makeNoteContextMenu(n: self.relatedNotes[indexPath.row], point: point, cellIndexPath: indexPath)
        })
    }
    
    private func makeNoteContextMenu(n: Note, point: CGPoint, cellIndexPath: IndexPath) -> UIMenu {
        let mergeAction = UIAction(title: "Merge", image: UIImage(systemName: "arrow.merge")) { action in
            let alert = UIAlertController(title: "Merge Note", message: "Are you sure you want to merge this note with the related note? This will delete the related note.", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Merge", style: .destructive, handler: { action in
                self.note.mergeWith(note: n)
                DataManager.save(file: self.note)
                if self.note != n {
                    DataManager.delete(file: n)
                }
                log.info("Merged notes.")
                self.refreshRelatedNotes()
                self.delegate?.mergedNotes(note1: self.note, note2: n)
            }))
            alert.addAction(UIAlertAction(title: "Cancel", style: .default, handler: { action in
                  log.info("Not merging note.")
            }))
            self.present(alert, animated: true, completion: nil)
        }
        let mergeTagsAction = UIAction(title: "Merge Tags", image: UIImage(systemName: "tag.fill")) { action in
            self.note.mergeTagsWith(note: n)
            DataManager.save(file: self.note)
        }
        return UIMenu(title: note.getName(), children: [mergeAction, mergeTagsAction])
    }
    
    private func refreshRelatedNotes() {
        Knowledge.setupSimilarityMatrix()
        let foundNotes = Knowledge.similarNotesFor(note: note)
        self.relatedNotes = [Note]()
        for (note, score) in foundNotes {
            if score > self.similarityLevel.rawValue {
                self.relatedNotes.append(note)
            }
        }
        collectionView.reloadData()
        countLabel.text = "Related Notes: (\(relatedNotes.count))"
    }
}

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
    func openRelatedNote(note: NoteX)
    func mergedNotes(note1: NoteX, note2: NoteX)
}

class RelatedNotesViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegate {
    
    var note: NoteX!
    var context: RelatedNotesContext! = .HomePage
    
    var relatedNotes = [NoteX]()
     var similarityThreshold: Float = 0.5
    
    var openNote: NoteX?
    var delegate: RelatedNotesVCDelegate?

    @IBOutlet weak var countLabel: UILabel!
    @IBOutlet weak var similaritySlider: UISlider!
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
    
    @IBAction func similaritySliderTouchUpInside(_ sender: UISlider) {
        refreshRelatedNotes()
    }
    
    @IBAction func similaritySliderTouchUpOutside(_ sender: UISlider) {
        refreshRelatedNotes()
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
    
    private func makeNoteContextMenu(n: NoteX, point: CGPoint, cellIndexPath: IndexPath) -> UIMenu {
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
        self.relatedNotes = [NoteX]()
        for (note, score) in foundNotes {
            if score > similaritySlider.value {
                self.relatedNotes.append(note)
            }
        }
        collectionView.reloadData()
        countLabel.text = "Related Notes: (\(relatedNotes.count))"
    }
}

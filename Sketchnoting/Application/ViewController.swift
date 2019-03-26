//
//  ViewController.swift
//  Sketchnoting
//
//  Created by Aryobarzan on 22/02/2019.
//  Copyright © 2019 Aryobarzan. All rights reserved.
//

import UIKit
import LGButton

class ViewController: UIViewController, UIGestureRecognizerDelegate {
    

    @IBOutlet var scrollView: UIScrollView!
    var notesStackView = UIStackView()
    
    var noteCollections = [NoteCollection]()
    var noteCollectionViews = [NoteCollectionView]()
    
    var selectedSketchnote: Sketchnote?

    override func viewDidLoad() {
        super.viewDidLoad()
 
        notesStackView.axis = .vertical
        notesStackView.distribution = .equalSpacing
        notesStackView.alignment = .fill
        notesStackView.spacing = 15
        scrollView.addSubview(notesStackView)
        notesStackView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            notesStackView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            notesStackView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            notesStackView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            notesStackView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            notesStackView.widthAnchor.constraint(equalTo: scrollView.widthAnchor)
            ])
        
        if let savedNoteCollections = loadNoteCollections() {
            noteCollections += savedNoteCollections
            for collection in noteCollections {
                displayNoteCollection(collection: collection)
            }
        }
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
        super.prepare(for: segue, sender: sender)
        switch(segue.identifier ?? "") {
        case "NewSketchnote":
            guard let sketchnoteViewController = segue.destination as? SketchNoteViewController else {
                fatalError("Unexpected destination")
            }
            sketchnoteViewController.new = true
            sketchnoteViewController.sketchnote = selectedSketchnote
        case "EditSketchnote":
            guard let sketchnoteViewController = segue.destination as? SketchNoteViewController else {
                fatalError("Unexpected destination")
            }
            sketchnoteViewController.new = false
            sketchnoteViewController.sketchnote = selectedSketchnote
        default:
            print("Not creating or editing sketchnote. (ignore this)")
        }
    }
    
    //MARK: Actions
    @IBAction func unwindToHome(sender: UIStoryboardSegue) {
        if let sourceViewController = sender.source as? SketchNoteViewController, let note = sourceViewController.sketchnote {
            
            var alreadyExists = false
            for i in 0..<noteCollectionViews.count {
                for j in 0..<noteCollectionViews[i].sketchnoteViews.count {
                    if noteCollectionViews[i].sketchnoteViews[j].sketchnote?.creationDate == note.creationDate {
                        noteCollectionViews[i].sketchnoteViews[j].setNote(note: note)
                        saveNoteCollections()
                        alreadyExists = true
                        break
                    }
                }
                if alreadyExists {
                    break
                }
            }
        }
    }
    private func saveNoteCollections() {
        let encoder = JSONEncoder()
        
        if let encoded = try? encoder.encode(noteCollections) {
            UserDefaults.standard.set(encoded, forKey: "NoteCollections")
            print("Note Collections saved.")
        }
        else {
            print("Encoding failed for note collections")
        }
    }
    
    private func loadNoteCollections() -> [NoteCollection]? {
        let decoder = JSONDecoder()
        
        if let data = UserDefaults.standard.data(forKey: "NoteCollections"),
            let loadedNoteCollections = try? decoder.decode([NoteCollection].self, from: data) {
            print("Note Collections loaded")
            return loadedNoteCollections
        }
        print("Failed to load note collections.")
        return nil
    }
    
    private func displaySketchnote(note: Sketchnote, collectionView: inout NoteCollectionView) {
        let sketchnoteView = SketchnoteView(frame: collectionView.stackView.frame)
        sketchnoteView.setNote(note: note)
        collectionView.sketchnoteViews.append(sketchnoteView)
        collectionView.stackView.addArrangedSubview(sketchnoteView)
        //collectionView.stackView.insertArrangedSubview(sketchnoteView, at: 0)
        
        let tap = UITapGestureRecognizer(target: self, action: #selector(self.handleSketchnoteTap(_:)))
        sketchnoteView.isUserInteractionEnabled = true
        sketchnoteView.addGestureRecognizer(tap)
    }
    
    private func displayNoteCollection(collection: NoteCollection) {
        var noteCollectionView = NoteCollectionView(frame: notesStackView.frame)
        noteCollectionView.setNoteCollection(collection: collection)
        self.noteCollectionViews.append(noteCollectionView)
        self.notesStackView.addArrangedSubview(noteCollectionView)
        //self.notesStackView.insertArrangedSubview(noteCollectionView, at: 0)
        
        noteCollectionView.setNewSketchnoteAction(for: .touchUpInside) {
            let newNote = Sketchnote(image: nil, relatedDocuments: nil, drawings: nil)!
            self.selectedSketchnote = newNote
            
            collection.addSketchnote(note: newNote)
            self.performSegue(withIdentifier: "NewSketchnote", sender: self)
            
            self.displaySketchnote(note: newNote, collectionView: &noteCollectionView)
        }
        
        for n in collection.notes {
            displaySketchnote(note: n, collectionView: &noteCollectionView)
        }
    }
    
    @objc func handleSketchnoteTap(_ sender: UITapGestureRecognizer) {
        let noteView = sender.view as! SketchnoteView
        self.selectedSketchnote = noteView.sketchnote
        self.performSegue(withIdentifier: "EditSketchnote", sender: self)
    }

    @IBAction func newNoteCollectionTapped(_ sender: LGButton) {
        let noteCollection = NoteCollection(title: "Untitled", notes: nil)!
        self.noteCollections.append(noteCollection)
        
        var noteCollectionView = NoteCollectionView(frame: notesStackView.frame)
        noteCollectionView.setNoteCollection(collection: noteCollection)
        self.noteCollectionViews.append(noteCollectionView)
        
        notesStackView.insertArrangedSubview(noteCollectionView, at: 0)
        
        noteCollectionView.setNewSketchnoteAction(for: .touchUpInside) {
            let newNote = Sketchnote(image: nil, relatedDocuments: nil, drawings: nil)!
            self.selectedSketchnote = newNote
            
            noteCollection.addSketchnote(note: newNote)
            self.displaySketchnote(note: newNote, collectionView: &noteCollectionView)
            
            self.performSegue(withIdentifier: "NewSketchnote", sender: self)
        }
        saveNoteCollections()
    }
}


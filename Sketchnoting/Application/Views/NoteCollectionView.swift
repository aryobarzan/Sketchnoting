//
//  NoteCollectionView.swift
//  Sketchnoting
//
//  Created by Aryobarzan on 25/03/2019.
//  Copyright © 2019 Aryobarzan. All rights reserved.
//

import UIKit
import LGButton

// This is the corresponding controller for a note collection view.
// This view contains every SketchnoteView that is displayed, as well as the note collection specific buttons such as Delete, Share, and New Sketchnote

class NoteCollectionView : UIView, UITextFieldDelegate {
    let kCONTENT_XIB_NAME = "NoteCollectionView"
    @IBOutlet var contentView: UIView!
    @IBOutlet var scrollView: UIScrollView!
    var stackView = UIStackView()
    @IBOutlet var titleField: UITextField!
    @IBOutlet var newSketchnoteButton: LGButton!
    @IBOutlet var deleteButton: LGButton!
    @IBOutlet var shareButton: LGButton!
    
    var parentViewController: ViewController!
    
    var noteCollection: NoteCollection?
    
    var sketchnoteViews = [SketchnoteView]()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        commonInit()
    }
    
    func commonInit() {
        Bundle.main.loadNibNamed(kCONTENT_XIB_NAME, owner: self, options: nil)
        self.widthAnchor.constraint(equalToConstant: 600).isActive = true
        self.heightAnchor.constraint(equalToConstant: 335).isActive = true
        contentView.fixInView(self)
        stackView.axis = .horizontal
        stackView.distribution = .equalSpacing
        stackView.alignment = .fill
        stackView.spacing = 15
        scrollView.addSubview(stackView)
        stackView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            stackView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            stackView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            stackView.heightAnchor.constraint(equalTo: scrollView.heightAnchor)
            ])
        titleField.delegate = self
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        // Hide the keyboard.
        textField.resignFirstResponder()
        if titleField.text == nil || titleField.text!.isEmpty {
            titleField.text = "Untitled"
        }
        self.noteCollection?.title = titleField.text!
        if self.noteCollection != nil {
            NotesManager.shared.updateTitle(noteCollection: self.noteCollection!)
        }
        return true
    }
    
    func setNoteCollection(collection: NoteCollection) {
        self.titleField.text = collection.title
        self.noteCollection = collection
    }
    
    @IBAction func newSketchnoteTapped(_ sender: LGButton) {
        let newNote = Sketchnote(image: nil, relatedDocuments: nil, drawings: nil)!
        noteCollection!.addSketchnote(note: newNote)
        
        parentViewController.selectedSketchnote = newNote
        parentViewController.performSegue(withIdentifier: "NewSketchnote", sender: self)
        parentViewController.displaySketchnote(note: newNote, collectionView: self)
    }
    
    func setDeleteAction(for controlEvents: UIControl.Event, _ closure: @escaping ()->()) {
        let sleeve = ClosureSleeve(closure)
        deleteButton.addTarget(sleeve, action: #selector(ClosureSleeve.invoke), for: controlEvents)
        objc_setAssociatedObject(self, String(format: "[%d]", arc4random()), sleeve, objc_AssociationPolicy.OBJC_ASSOCIATION_RETAIN)
    }
    
    func setShareAction(_ closure: @escaping ()->()) {
        let sleeve = ClosureSleeve(closure)
        shareButton.addTarget(sleeve, action: #selector(ClosureSleeve.invoke), for: .touchUpInside)
        objc_setAssociatedObject(self, String(format: "[%d]", arc4random()), sleeve, objc_AssociationPolicy.OBJC_ASSOCIATION_RETAIN)
    }
    
    func applySearchFilters(filters: [String]) {
        for j in 0..<sketchnoteViews.count {
            
            var matchingFilters = 0
            for filter in filters {
                var found = false
                for doc in sketchnoteViews[j].sketchnote?.relatedDocuments ?? [Document]() {
                    if doc.title.lowercased().contains(filter) || (doc.description != nil && !doc.description!.isEmpty && doc.description!.lowercased().contains(filter)) || (doc.entityType != nil && !doc.entityType!.isEmpty && doc.entityType!.contains(filter)) {
                        found = true
                        matchingFilters += 1
                        break
                    }
                }
                if !found {
                    if (sketchnoteViews[j].sketchnote?.recognizedText?.lowercased().contains(filter) ?? false) || (sketchnoteViews[j].sketchnote?.drawings?.contains(filter) ?? false) {
                        found = true
                        matchingFilters += 1
                    }
                    else {
                        found = false
                    }
                }
            }
            if matchingFilters == filters.count {
                sketchnoteViews[j].isHidden = false
            }
            else {
                sketchnoteViews[j].isHidden = true
            }
        }
    }
    
    func showSketchnotes() {
        for view in sketchnoteViews {
            view.isHidden = false
        }
    }
    
}
class ClosureSleeve {
    let closure: ()->()
    
    init (_ closure: @escaping ()->()) {
        self.closure = closure
    }
    
    @objc func invoke () {
        closure()
    }
}


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

class NoteCollectionView : UIView, UITextFieldDelegate, DocumentVisitor {
    
    let kCONTENT_XIB_NAME = "NoteCollectionView"
    @IBOutlet var contentView: UIView!
    @IBOutlet var scrollView: UIScrollView!
    var stackView = UIStackView()
    @IBOutlet var titleField: UITextField!
    @IBOutlet var newSketchnoteButton: LGButton!
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
        newNote.save()
        noteCollection!.save()
        
        parentViewController.selectedSketchnote = newNote
        parentViewController.performSegue(withIdentifier: "NewSketchnote", sender: self)
        parentViewController.displaySketchnote(note: newNote, collectionView: self)
    }
    
    func setShareAction(_ closure: @escaping ()->()) {
        let sleeve = ClosureSleeve(closure)
        shareButton.addTarget(sleeve, action: #selector(ClosureSleeve.invoke), for: .touchUpInside)
        objc_setAssociatedObject(self, String(format: "[%d]", arc4random()), sleeve, objc_AssociationPolicy.OBJC_ASSOCIATION_RETAIN)
    }
    
    var currentSketchnoteViewForSearch : SketchnoteView!
    var currentSearchFilter : String!
    func applySearchFilters(filters: [String]) {
        for j in 0..<sketchnoteViews.count {
            currentSketchnoteViewForSearch = sketchnoteViews[j]
            
            for filter in filters {
                if (sketchnoteViews[j].sketchnote?.recognizedText?.lowercased().contains(filter) ?? false) || (sketchnoteViews[j].sketchnote?.drawings?.contains(filter) ?? false) {
                    sketchnoteViews[j].matchesSearch = true
                }
                else {
                    sketchnoteViews[j].matchesSearch = false
                    currentSearchFilter = filter
                    if let documents = sketchnoteViews[j].sketchnote?.relatedDocuments {
                        for doc in documents {
                            doc.accept(visitor: self)
                            if sketchnoteViews[j].matchesSearch {
                                break
                            }
                        }
                    }
                }
            }
            if sketchnoteViews[j].matchesSearch {
                sketchnoteViews[j].isHidden = false
            }
            else {
                sketchnoteViews[j].isHidden = true
            }
        }
    }
    
    //MARK: Visitors for searching for terms in the various document types of a note
    func process(document: Document) {
       let _ = self.processBaseDocumentSearch(document: document)
    }
    
    func process(document: SpotlightDocument) {
        if !processBaseDocumentSearch(document: document) {
            if let label = document.label {
                if label.lowercased().contains(currentSearchFilter) {
                    currentSketchnoteViewForSearch.matchesSearch = true
                }
            }
            if let types = document.types {
                for type in types {
                    if type.lowercased().contains(currentSearchFilter) {
                        currentSketchnoteViewForSearch.matchesSearch = true
                        break
                    }
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
        if document.title.lowercased().contains(currentSearchFilter) {
            currentSketchnoteViewForSearch.matchesSearch = true
            return true
        }
        else if let description = document.description {
            if description.lowercased().contains(currentSearchFilter) {
                currentSketchnoteViewForSearch.matchesSearch = true
                return true
            }
        }
        return false
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


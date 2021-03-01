//
//  NoteInfoViewController.swift
//  Sketchnoting
//
//  Created by Aryobarzan on 03/07/2020.
//  Copyright © 2020 Aryobarzan. All rights reserved.
//

import UIKit

class NoteInfoViewController: UIViewController {

    @IBOutlet weak var titleTextField: UITextField!
    @IBOutlet weak var creationDateLabel: UILabel!
    @IBOutlet weak var updateDateLabel: UILabel!
    @IBOutlet weak var pageIndexLabel: UILabel!
    
    var delegate: NoteInfoDelegate?
    var note: (URL, Note)!
    override func viewDidLoad() {
        super.viewDidLoad()

        titleTextField.text = note.1.getName()
        creationDateLabel.text = "\(NeoLibrary.getCreationDate(url: note.0).getFormattedDate())"
        updateDateLabel.text = "\(NeoLibrary.getModificationDate(url: note.0).getFormattedDate())"
        pageIndexLabel.text = "\(note.1.activePageIndex+1)/\(Int(note.1.pages.count))"
    }
    
    @IBAction func titleTextViewDone(_ sender: UITextField) {
        if let text = sender.text {
            log.info("Note title updated.")
            let newURL = NeoLibrary.rename(url: note.0, file: note.1, name: text)
            if let newURL = newURL {
                delegate?.noteRenamed(newName: text, newURL: newURL)
            }
        }
        sender.text = note.1.getName()
    }
    
}

protocol NoteInfoDelegate {
    func noteRenamed(newName: String, newURL: URL)
}

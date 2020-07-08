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
    
    var delegate: NoteInfoDelegate?
    var note: (URL, Note)!
    override func viewDidLoad() {
        super.viewDidLoad()

        titleTextField.text = note.1.getName()
        creationDateLabel.text = "\(NeoLibrary.getCreationDate(url: note.0).getFormattedDate())"
        updateDateLabel.text = "\(NeoLibrary.getModificationDate(url: note.0).getFormattedDate())"
    }
    
    @IBAction func titleTextViewDone(_ sender: UITextField) {
        if let text = sender.text {
            log.info("Note title updated.")
            _ = NeoLibrary.rename(url: note.0, file: note.1, name: text)
            delegate?.noteTitleUpdated(title: text)
        }
        sender.text = note.1.getName()
    }
    
}

protocol NoteInfoDelegate {
    func noteTitleUpdated(title: String)
}

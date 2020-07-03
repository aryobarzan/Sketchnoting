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
    override func viewDidLoad() {
        super.viewDidLoad()

        titleTextField.text = DataManager.activeNote!.getName()
        creationDateLabel.text = "\(DataManager.activeNote!.creationDate.getFormattedDate())"
        updateDateLabel.text = "\(DataManager.activeNote!.updateDate.getFormattedDate())"
    }
    
    @IBAction func titleTextViewDone(_ sender: UITextField) {
        if let text = sender.text {
            DataManager.activeNote!.setName(name: text)
            log.info("Note title updated.")
            DataManager.saveCurrentNote()
            delegate?.noteTitleUpdated(title: DataManager.activeNote!.getName())
        }
        sender.text = DataManager.activeNote!.getName()
        
    }
    
}

protocol NoteInfoDelegate {
    func noteTitleUpdated(title: String)
}

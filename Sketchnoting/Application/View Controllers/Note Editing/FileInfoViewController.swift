//
//  NoteInfoViewController.swift
//  Sketchnoting
//
//  Created by Aryobarzan on 03/07/2020.
//  Copyright © 2020 Aryobarzan. All rights reserved.
//

import UIKit

class FileInfoViewController: UIViewController {

    @IBOutlet weak var titleTextField: UITextField!
    @IBOutlet weak var creationDateLabel: UILabel!
    @IBOutlet weak var updateDateLabel: UILabel!
    @IBOutlet weak var pageIndexLabel: UILabel!
    
    var file: (URL, File)!
    
    var renameCompletion: ((String, URL) -> (Void))?
    override func viewDidLoad() {
        super.viewDidLoad()
        titleTextField.text = file.1.getName()
        creationDateLabel.text = "\(NeoLibrary.getCreationDate(url: file.0).getFormattedDate())"
        updateDateLabel.text = "\(NeoLibrary.getModificationDate(url: file.0).getFormattedDate())"
        if file.1 is Note {
            if let note = file.1 as? Note {
                pageIndexLabel.text = "\(note.activePageIndex+1)/\(Int(note.pages.count))"
                pageIndexLabel.isHidden = false
            }
        }
        else {
            pageIndexLabel.isHidden = true
        }
    }
    
    @IBAction func titleTextViewDone(_ sender: UITextField) {
        if let text = sender.text {
            logger.info("File renamed.")
            var newName = text
            let newURL = NeoLibrary.rename(url: file.0, file: file.1, name: text)
            if let newURL = newURL {
                newName = newURL.deletingPathExtension().lastPathComponent
                if let note = file.1 as? Note {
                    note.setName(name: newName)
                    NeoLibrary.saveSynchronously(note: note, url: newURL)
                }
                if let renameCompletion = renameCompletion {
                    renameCompletion(newName, newURL)
                }
            }
        }
        sender.text = file.1.getName()
    }
}

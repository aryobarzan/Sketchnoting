//
//  NoteTextViewController.swift
//  Sketchnoting
//
//  Created by Aryobarzan on 08/11/2019.
//  Copyright © 2019 Aryobarzan. All rights reserved.
//

import UIKit

class NoteTextViewController: UIViewController {

    
    @IBOutlet var textView: UITextView!
    var note: NoteX?
    override func viewDidLoad() {
        super.viewDidLoad()

        if let note = note {
            self.title = note.getName()
            textView.text = note.getText()
        }
    }
   
    @IBAction func copyTapped(_ sender: UIBarButtonItem) {
        if let note = note {
            UIPasteboard.general.string = note.getText()
            self.view.makeToast("Copied text to clipboard.")
        }
    }
    
    @IBAction func closeTapped(_ sender: UIBarButtonItem) {
        dismiss(animated: true, completion: nil)
    }
}

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
    var note: (URL, Note)!
    override func viewDidLoad() {
        super.viewDidLoad()
        self.title = note.1.getName()
        textView.text = note.1.getText()
    }
   
    @IBAction func copyTapped(_ sender: UIBarButtonItem) {
        UIPasteboard.general.string = note.1.getText()
        self.view.makeToast("Copied text to clipboard.")
    }
    
    @IBAction func closeTapped(_ sender: UIBarButtonItem) {
        dismiss(animated: true, completion: nil)
    }
}

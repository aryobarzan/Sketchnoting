//
//  TextBoxViewController.swift
//  Sketchnoting
//
//  Created by Aryobarzan on 17/05/2020.
//  Copyright © 2020 Aryobarzan. All rights reserved.
//

import UIKit
import Highlightr

protocol TextBoxViewControllerDelegate {
    func noteTypedTextSaveTriggered(typedText: NoteTypedText)
}

class TextBoxViewController: UIViewController {
    
    var delegate: TextBoxViewControllerDelegate?
    
    var noteTypedText: NoteTypedText!

    @IBOutlet weak var textView: UITextView!
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let highlightr = Highlightr()!
        var highlightedText = highlightr.highlight(noteTypedText.text)
        if !noteTypedText.codeLanguage.isEmpty {
            highlightedText = highlightr.highlight(noteTypedText.text, as: noteTypedText.codeLanguage)
        }
        textView.attributedText = highlightedText
    }
    
    @IBAction func cancelTapped(_ sender: UIBarButtonItem) {
        self.dismiss(animated: true, completion: nil)
    }
    
    @IBAction func saveTapped(_ sender: UIBarButtonItem) {
        noteTypedText.text = textView.text
        self.delegate?.noteTypedTextSaveTriggered(typedText: noteTypedText)
        self.dismiss(animated: true, completion: nil)
    }
}

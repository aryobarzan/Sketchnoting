//
//  NoteTextViewController.swift
//  Sketchnoting
//
//  Created by Aryobarzan on 08/11/2019.
//  Copyright © 2019 Aryobarzan. All rights reserved.
//

import UIKit

class NoteTextViewController: UIViewController {

    @IBOutlet weak var pagesSegmentedControl: UISegmentedControl!
    @IBOutlet weak var textSegmentedControl: UISegmentedControl!
    @IBOutlet var textView: UITextView!
    
    var note: (URL, Note)!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.title = note.1.getName()
        textView.text = getText()
    }
    
    private func getText() -> String {
        // Current page
        if pagesSegmentedControl.selectedSegmentIndex == 0 {
            if textSegmentedControl.selectedSegmentIndex == 0 { // Full text
                return note.1.getCurrentPage().getText(option: .FullText)
            }
            else if textSegmentedControl.selectedSegmentIndex == 1 { // Handwritten text
                return note.1.getCurrentPage().getText(option: .HandwrittenText)
            }
            else { // PDF text
                return note.1.getCurrentPage().getText(option: .PDFText)
            }
        }
        // Full Note
        else {
            if textSegmentedControl.selectedSegmentIndex == 0 { // Full text
                return note.1.getText(option: .FullText)
            }
            else if textSegmentedControl.selectedSegmentIndex == 1 { // Handwritten tex
                return note.1.getText(option: .HandwrittenText)
            }
            else { // PDF text
                return note.1.getText(option: .PDFText)
            }
        }
    }
   
    @IBAction func copyTapped(_ sender: UIBarButtonItem) {
        UIPasteboard.general.string = textView.text
        self.view.makeToast("Copied text to clipboard.")
    }
    
    @IBAction func closeTapped(_ sender: UIBarButtonItem) {
        dismiss(animated: true, completion: nil)
    }
    @IBAction func pagesSegmentedControlChanged(_ sender: UISegmentedControl) {
        textView.text = getText()
    }
    @IBAction func textSegmentedControlChanged(_ sender: UISegmentedControl) {
        textView.text = getText()
    }
}

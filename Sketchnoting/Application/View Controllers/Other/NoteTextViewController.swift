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
    @IBOutlet weak var parsingSegmentedControl: UISegmentedControl!
    @IBOutlet weak var summarizeSwitch: UISwitch!
    @IBOutlet var textView: UITextView!
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    
    var note: (URL, Note)!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.title = note.1.getName()
        textView.text = getText()
    }
    
    private func getText() -> String {
        var text = ""
        summarizeSwitch.setOn(false, animated: true)
        // Current page
        if pagesSegmentedControl.selectedSegmentIndex == 0 {
            if textSegmentedControl.selectedSegmentIndex == 0 { // Full text
                text = note.1.getCurrentPage().getText(option: .FullText)
            }
            else if textSegmentedControl.selectedSegmentIndex == 1 { // Handwritten text
                text = note.1.getCurrentPage().getText(option: .HandwrittenText)
            }
            else { // PDF text
                text = note.1.getCurrentPage().getText(option: .PDFText)
            }
        }
        // Full Note
        else {
            if textSegmentedControl.selectedSegmentIndex == 0 { // Full text
                text = note.1.getText(option: .FullText)
            }
            else if textSegmentedControl.selectedSegmentIndex == 1 { // Handwritten text
                text = note.1.getText(option: .HandwrittenText)
            }
            else { // PDF text
                text = note.1.getText(option: .PDFText)
            }
        }
        if parsingSegmentedControl.selectedSegmentIndex == 1 {
            text = TextParser.shared.clean(text: text)
        }
        return text
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
    @IBAction func parsingSegmentedControlChanged(_ sender: UISegmentedControl) {
        textView.text = getText()
    }
    @IBAction func summarizeSwitchChanged(_ sender: UISwitch) {
        if sender.isOn {
            textSegmentedControl.isEnabled = false
            pagesSegmentedControl.isEnabled = false
            parsingSegmentedControl.isEnabled = false
            activityIndicator.isHidden = false
            Reductio.shared.summarize(text: textView.text, compression: 0.8, completion: { phrases in
                    logger.info("Summarized version has \(phrases.count) sentences.")
                    DispatchQueue.main.async {
                        self.textSegmentedControl.isEnabled = true
                        self.pagesSegmentedControl.isEnabled = true
                        self.parsingSegmentedControl.isEnabled = true
                        self.activityIndicator.isHidden = true
                        self.textView.text = phrases.joined(separator: " ")
                    }
            })
        }
        else {
            textView.text = getText()
        }
    }
}

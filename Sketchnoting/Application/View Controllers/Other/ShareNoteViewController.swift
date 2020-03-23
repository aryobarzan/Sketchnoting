//
//  ShareNoteViewController.swift
//  Sketchnoting
//
//  Created by Kael on 15/11/2019.
//  Copyright © 2019 Aryobarzan. All rights reserved.
//

import UIKit

class ShareNoteViewController: UIViewController {

    @IBOutlet var typeSegmentedControl: UISegmentedControl!
    @IBOutlet var pageNumberField: UITextField!
    @IBOutlet var fileButton: UIButton!
    @IBOutlet var pdfButton: UIButton!
    @IBOutlet var imageButton: UIButton!
    
    var note: NoteX!
    override func viewDidLoad() {
        super.viewDidLoad()
        fileButton.layer.borderColor = UIColor.white.cgColor
        fileButton.layer.borderWidth = 1
        fileButton.layer.cornerRadius = 5
        pdfButton.layer.borderColor = UIColor.white.cgColor
        pdfButton.layer.borderWidth = 1
        pdfButton.layer.cornerRadius = 5
        imageButton.layer.borderColor = UIColor.white.cgColor
        imageButton.layer.borderWidth = 1
        imageButton.layer.cornerRadius = 5
    }
    
    @IBAction func typeSegmentedControlChanged(_ sender: UISegmentedControl) {
        if sender.selectedSegmentIndex == 0 { // Entire Note
            imageButton.isEnabled = false
            fileButton.isEnabled = true
            pageNumberField.isEnabled = false
        }
        else { // Specific Page
            imageButton.isEnabled = true
            fileButton.isEnabled = false
            pageNumberField.isEnabled = true
        }
    }
    @IBAction func fileTapped(_ sender: UIButton) { // 0
        share(asType: 0)
    }
    @IBAction func pdfTapped(_ sender: UIButton) { // 1
        share(asType: 1)
    }
    @IBAction func imageTapped(_ sender: UIButton) { // 2
        share(asType: 2)
    }
    
    private func validatePageNumber() -> Bool {
        if pageNumberField.text != nil && Int(pageNumberField.text!) != nil {
            let number = Int(pageNumberField.text!)! - 1
            if number >= 0 && number < note.pages.count {
                return true
            }
            return false
        }
        return false
    }
    
    private func share(asType: Int) {
        if typeSegmentedControl.selectedSegmentIndex == 1 && !validatePageNumber() {
            return
        }
        if asType == 0 {
            let noteURL = SKFileManager.getNotesDirectory().appendingPathComponent(note.id + ".sketchnote")
            if FileManager.default.fileExists(atPath: noteURL.path) {
                let activityController = UIActivityViewController(activityItems: [noteURL], applicationActivities: nil)
                self.present(activityController, animated: true, completion: nil)
                if let popOver = activityController.popoverPresentationController {
                    popOver.sourceView = fileButton
                }
            }
        }
        else if asType == 1 {
            var pdf = note.createPDF()
            if typeSegmentedControl.selectedSegmentIndex == 1 {
                pdf = note.pages[Int(pageNumberField.text!)! - 1].createPDF()
            }
            if let pdf = pdf {
                let activityController = UIActivityViewController(activityItems: [pdf], applicationActivities: nil)
                self.present(activityController, animated: true, completion: nil)
                if let popOver = activityController.popoverPresentationController {
                    popOver.sourceView = pdfButton
                }
            }
        }
        else {
            let page = note.pages[Int(pageNumberField.text!)! - 1]
            page.getAsImage() { image in
                if let jpegData = image.jpegData(compressionQuality: 1) {
                    let activityController = UIActivityViewController(activityItems: [jpegData], applicationActivities: nil)
                        self.present(activityController, animated: true, completion: nil)
                        if let popOver = activityController.popoverPresentationController {
                            popOver.sourceView = self.imageButton
                        }
                    }
                }
            }
    }
    @IBAction func doneTapped(_ sender: UIBarButtonItem) {
        self.dismiss(animated: true, completion: nil)
    }
}

//
//  NoteOptionsTableViewController.swift
//  Sketchnoting
//
//  Created by Aryobarzan on 08/11/2019.
//  Copyright © 2019 Aryobarzan. All rights reserved.
//

import UIKit

class NoteOptionsTableViewController: UITableViewController {
    
    var delegate: NoteOptionsDelegate?
    var canDeletePage = false

    @IBOutlet weak var nameField: UITextField!
    @IBOutlet weak var dateLabel: UILabel!
    @IBOutlet weak var pageLabel: UILabel!
    @IBOutlet weak var drawingsTextView: UITextView!
    @IBOutlet weak var pdfScaleSlider: UISlider!
    @IBOutlet weak var clearPDFPageButton: UIButton!
    
    @IBOutlet var deletePageButton: UIButton!
    override func viewDidLoad() {
        super.viewDidLoad()
        self.clearsSelectionOnViewWillAppear = false
        deletePageButton.isEnabled = canDeletePage
        
        nameField.text = SKFileManager.activeNote!.getName()
        dateLabel.text = "\(SKFileManager.activeNote!.creationDate.getFormattedDate())"
        pageLabel.text = "Page: \(SKFileManager.activeNote!.activePageIndex+1)/\(SKFileManager.activeNote!.pages.count)"
        drawingsTextView.text = "Drawings: \(SKFileManager.activeNote!.getCurrentPage().drawingLabels.joined(separator:" - "))"
        
        if SKFileManager.activeNote!.getCurrentPage().getPDFDocument() != nil {
            pdfScaleSlider.isEnabled = true
            clearPDFPageButton.isEnabled = true
        }
        else {
            pdfScaleSlider.isEnabled = false
            clearPDFPageButton.isEnabled = false
        }
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        var option : NoteOption = .Annotate
        if indexPath.section == 1 {
            if indexPath.row == 0 {
                option = .Annotate
            }
        }
        else if indexPath.section == 2 {
            if indexPath.row == 0 {
                    option = .ViewText
            }
            else if indexPath.row == 1 {
                    option = .CopyText
            }
            else if indexPath.row == 2 {
                        option = .Share
            }
            else if indexPath.row == 3 {
                    option = .ClearPage
            }
            else if indexPath.row == 4 {
                    option = .DeletePage
            }
        }
        else if indexPath.section == 3 {
            if indexPath.row == 1 {
                option = .ClearPDFPage
            }
        }
        else if indexPath.section == 4 {
            if indexPath.row == 0 {
                option = .ResetDocuments
            }
            else if indexPath.row == 1 {
                option = .ResetTextRecognition
            }
            else if indexPath.row == 2 {
                option = .DeleteNote
            }
        }
        dismiss(animated: true, completion: nil)
        delegate?.noteOptionSelected(option: option)
    }
    @IBAction func nameFieldDone(_ sender: UITextField) {
        if let newName = sender.text {
            if newName != SKFileManager.activeNote!.getName() {
                SKFileManager.activeNote!.setName(name: newName)
                log.info("Updated note name.")
                SKFileManager.save(file: SKFileManager.activeNote!)
            }
        }
    }
    @IBAction func pdfScaleSliderChanged(_ sender: UISlider) {
        var scale = sender.value
        if scale == 0.0 {
            scale = 0.1
        }
        delegate?.pdfScaleChanged(scale: scale)
    }
}

protocol NoteOptionsDelegate  {
    func noteOptionSelected(option: NoteOption)
    func pdfScaleChanged(scale: Float)
}

enum NoteOption {
    case Annotate
    case SetTitle
    case ViewText
    case CopyText
    case ClearPage
    case DeletePage
    case Share
    case ClearPDFPage
    case ResetDocuments
    case ResetTextRecognition
    case DeleteNote
}

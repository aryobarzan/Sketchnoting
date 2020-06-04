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
    @IBOutlet weak var clearPDFPageButton: UIButton!
    @IBOutlet weak var clearPDFPageView: UIView!
    @IBOutlet weak var pdfScaleLabel: UILabel!
    @IBOutlet weak var pdfScaleStepper: UIStepper!
    @IBOutlet weak var resetPDFScaleButton: UIButton!
    
    @IBOutlet var deletePageButton: UIButton!
    override func viewDidLoad() {
        super.viewDidLoad()
        self.clearsSelectionOnViewWillAppear = false
        deletePageButton.isEnabled = canDeletePage
        
        nameField.text = DataManager.activeNote!.getName()
        dateLabel.text = "\(DataManager.activeNote!.creationDate.getFormattedDate())"
        pageLabel.text = "Page: \(DataManager.activeNote!.activePageIndex+1)/\(DataManager.activeNote!.pages.count)"
        drawingsTextView.text = "Drawings: \(DataManager.activeNote!.getCurrentPage().drawingLabels.joined(separator:" - "))"
        
        pdfScaleStepper.minimumValue = 0.1
        pdfScaleStepper.maximumValue = 2.0
        pdfScaleStepper.stepValue = 0.1
        pdfScaleStepper.value = 1.0
        
        if DataManager.activeNote!.getCurrentPage().getPDFDocument() != nil {
            pdfScaleStepper.isEnabled = true
            clearPDFPageButton.isEnabled = true
            clearPDFPageView.isUserInteractionEnabled = true
            resetPDFScaleButton.isEnabled = true
            let currentScale = DataManager.activeNote!.getCurrentPage().pdfScale ?? 1.0
            pdfScaleLabel.text = "Scale: \(currentScale)"
            pdfScaleStepper.value = Double(currentScale)
        }
        else {
            pdfScaleStepper.isEnabled = false
            clearPDFPageButton.isEnabled = false
            clearPDFPageView.isUserInteractionEnabled = false
            resetPDFScaleButton.isEnabled = false
        }
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        var option : NoteOption = .Annotate
        if indexPath.section == 1 {
            if indexPath.row == 0 {
                option = .Annotate
            }
            else if indexPath.row == 1 {
                option = .RelatedNotes
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
                    option = .MoveFile
            }
            else if indexPath.row == 3 {
                        option = .Share
            }
            else if indexPath.row == 4 {
                    option = .ClearPage
            }
            else if indexPath.row == 5 {
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
            if newName != DataManager.activeNote!.getName() {
                DataManager.activeNote!.setName(name: newName)
                log.info("Updated note name.")
                DataManager.save(file: DataManager.activeNote!)
            }
        }
    }

    @IBAction func pdfScaleStepperChanged(_ sender: UIStepper) {
        var scale = Float(sender.value)
        if scale == 0.0 {
            scale = 0.1
        }
        pdfScaleLabel.text = "Scale: \(scale)"
        delegate?.pdfScaleChanged(scale: scale)
    }
    @IBAction func resetPDFScaleTapped(_ sender: UIButton) {
        if pdfScaleStepper.value != 1.0 {
            pdfScaleLabel.text = "Scale: 1.0"
            pdfScaleStepper.value = 1.0
            delegate?.pdfScaleChanged(scale: 1.0)
        }
    }
}

protocol NoteOptionsDelegate  {
    func noteOptionSelected(option: NoteOption)
    func pdfScaleChanged(scale: Float)
}

enum NoteOption {
    case Annotate
    case RelatedNotes
    case SetTitle
    case ViewText
    case CopyText
    case MoveFile
    case ClearPage
    case DeletePage
    case Share
    case ClearPDFPage
    case ResetDocuments
    case ResetTextRecognition
    case DeleteNote
}

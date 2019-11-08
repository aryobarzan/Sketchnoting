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

    override func viewDidLoad() {
        super.viewDidLoad()
        self.clearsSelectionOnViewWillAppear = false
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        var option : NoteOption = .Annotate
        if indexPath.section == 0 {
            if indexPath.row == 0 {
                option = .Annotate
            }
        }
        else if indexPath.section == 1 {
            if indexPath.row == 0 {
                option = .SetTitle
            }
            else if indexPath.row == 1 {
                    option = .ViewText
                }
            else if indexPath.row == 2 {
                    option = .CopyText
            }
        }
        else if indexPath.section == 2 {
            if indexPath.row == 0 {
                option = .ShareAsImage
            }
            else if indexPath.row == 1 {
                option = .ShareAsPDF
            }
            else if indexPath.row == 2 {
                option = .ShareAsFile
            }
        }
        else if indexPath.section == 3 {
            if indexPath.row == 0 {
                option = .ResetDocuments
            }
            else if indexPath.row == 1 {
                option = .ResetTextRecognition
            }
            else if indexPath.row == 2 {
                option = .ClearNote
            }
        }
        dismiss(animated: true, completion: nil)
        delegate?.noteOptionSelected(option: option)
    }
}

protocol NoteOptionsDelegate  {
    func noteOptionSelected(option: NoteOption)
}

enum NoteOption {
    case Annotate
    case SetTitle
    case ViewText
    case CopyText
    case ShareAsImage
    case ShareAsPDF
    case ShareAsFile
    case ResetDocuments
    case ResetTextRecognition
    case ClearNote
}

//
//  BookshelfOptionsTableViewController.swift
//  Sketchnoting
//
//  Created by Aryobarzan on 09/11/2019.
//  Copyright © 2019 Aryobarzan. All rights reserved.
//

import UIKit

class BookshelfOptionsTableViewController: UITableViewController {

    
    var currentFilter: BookshelfFilter?
    var delegate: BookshelfOptionsDelegate?
    @IBOutlet var filterAllCheckmark: UIImageView!
    @IBOutlet var filterTAGMECheckmark: UIImageView!
    @IBOutlet var filterSpotlightCheckmark: UIImageView!
    @IBOutlet var filterBioPortalCheckmark: UIImageView!
    @IBOutlet var filterCHEBICheckmark: UIImageView!
    override func viewDidLoad() {
        super.viewDidLoad()
        self.clearsSelectionOnViewWillAppear = true
        if currentFilter == nil {
            currentFilter = .All
        }
        switch currentFilter! {
        case .All:
            filterAllCheckmark.isHidden = false
        case .TAGME:
            filterTAGMECheckmark.isHidden = false
        case .Spotlight:
            filterSpotlightCheckmark.isHidden = false
        case .BioPortal:
            filterBioPortalCheckmark.isHidden = false
        case .CHEBI:
            filterCHEBICheckmark.isHidden = false
        }
    }
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
            var option : BookshelfOption = .FilterAll
            if indexPath.section == 0 {
                if indexPath.row == 0 {
                    option = .FilterAll
                }
                else if indexPath.row == 1 {
                    option = .FilterTAGME
                }
                else if indexPath.row == 2 {
                    option = .FilterSpotlight
                }
                else if indexPath.row == 3 {
                    option = .FilterBioPortal
                }
                else if indexPath.row == 4 {
                    option = .FilterCHEBI
                }
            }
            else if indexPath.section == 1 {
                if indexPath.row == 0 {
                    option = .ResetDocuments
                }
            }
            dismiss(animated: true, completion: nil)
            delegate?.bookshelfOptionSelected(option: option)
        }
    }

    protocol BookshelfOptionsDelegate  {
        func bookshelfOptionSelected(option: BookshelfOption)
    }

    enum BookshelfOption {
        case FilterAll
        case FilterTAGME
        case FilterSpotlight
        case FilterBioPortal
        case FilterCHEBI
        case ResetDocuments
    }

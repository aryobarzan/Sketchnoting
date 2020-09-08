//
//  ShareItemViewCell.swift
//  Sketchnoting
//
//  Created by Aryobarzan on 04/09/2020.
//  Copyright © 2020 Aryobarzan. All rights reserved.
//

import UIKit

class ExportItemViewCell: UICollectionViewCell {
    
    @IBOutlet weak var typeImageView: UIImageView!
    @IBOutlet weak var typeLabel: UILabel!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var exportingAsLabel: UILabel!
    
    func setItem(file: File, url: URL) {
        if let note = file as? Note {
            self.typeLabel.text = "Note"
            self.typeImageView.image = UIImage(systemName: "doc.circle")
            self.titleLabel.text = note.getName()
            self.exportingAsLabel.text = "Exporting as: PDF"
        }
        else {
            self.typeLabel.text = "Folder"
            self.typeImageView.image = UIImage(systemName: "folder.circle")
            self.titleLabel.text = file.getName()
            self.exportingAsLabel.text = "Exporting as: Sketchnote"
        }
    }
    
    func update(exportType: ExportAsType) {
        switch exportType {
        case .PDF:
            self.exportingAsLabel.text = "Exporting as: PDF"
            break
        case .Image:
            self.exportingAsLabel.text = "Exporting as: Image"
            break
        case .Sketchnote:
            self.exportingAsLabel.text = "Exporting as: Sketchnote"
            break
        }
    }
}


//
//  DocumentUICollectionViewCell.swift
//  Sketchnoting
//
//  Created by Aryobarzan on 15/07/2019.
//  Copyright © 2019 Aryobarzan. All rights reserved.
//

import UIKit

class DocumentUICollectionViewCell: UICollectionViewCell {
    
    var delegate: DocumentCollectionViewCellDelegate!
    var document: Document!
    
    @IBOutlet var titleLabel: UILabel!
    @IBOutlet var typeLabel: UILabel!
    @IBOutlet var previewImage: UIImageView!
    @IBOutlet var topView: UIView!
    @IBOutlet var abstractTextView: UITextView!
    @IBOutlet var typeLabelView: UIView!
    @IBOutlet var hideButton: UIButton!
    @IBAction func hideTapped(_ sender: UIButton) {
        delegate.documentCollectionViewCellHideTapped(document: document, sender: self)
    }
}

protocol DocumentCollectionViewCellDelegate {
    func documentCollectionViewCellHideTapped(document: Document, sender: DocumentUICollectionViewCell)
}

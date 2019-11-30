//
//  DocumentViewCell.swift
//  Sketchnoting
//
//  Created by Aryobarzan on 29/11/2019.
//  Copyright © 2019 Aryobarzan. All rights reserved.
//

import UIKit

class DocumentViewCell: UICollectionViewCell {
    var document: Document!
    @IBOutlet var previewImage: UIImageView!
    @IBOutlet var titleLabel: UILabel!
}

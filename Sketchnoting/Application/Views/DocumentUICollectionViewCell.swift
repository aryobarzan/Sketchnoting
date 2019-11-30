//
//  DocumentUICollectionViewCell.swift
//  Sketchnoting
//
//  Created by Aryobarzan on 15/07/2019.
//  Copyright © 2019 Aryobarzan. All rights reserved.
//

import UIKit

class DocumentUICollectionViewCell: UICollectionViewCell {
    
    var document: Document!
    
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var previewImage: UIImageView!
}

//
//  NoteCollectionViewCell.swift
//  Sketchnoting
//
//  Created by Aryobarzan on 20/08/2019.
//  Copyright © 2019 Aryobarzan. All rights reserved.
//

import UIKit
import UICircularProgressRing

class NoteCollectionViewCell: UICollectionViewCell {
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var titleBackgroundView: UIView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var similarityWeightProgressRing: UICircularProgressRing!
    
    var file: File?
        
    override func awakeFromNib() {
        super.awakeFromNib()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    func setFile(file: File) {
        self.imageView.layer.borderWidth = 1
        self.imageView.layer.borderColor = UIColor.black.cgColor
        self.imageView.layer.cornerRadius = 6
        
        self.file = file
        file.getPreviewImage() { image in
            self.imageView.image = image
        }
        titleLabel.text = file.getName()
        similarityWeightProgressRing.isHidden = true
    }
    
    func showSimilarityRing(weight: Double, max: Double) {
        similarityWeightProgressRing.maxValue = CGFloat(max)
        similarityWeightProgressRing.value = CGFloat(weight)
        similarityWeightProgressRing.isHidden = false
    }
}

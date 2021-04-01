//
//  NoteCollectionViewCell.swift
//  Sketchnoting
//
//  Created by Aryobarzan on 20/08/2019.
//  Copyright © 2019 Aryobarzan. All rights reserved.
//

import UIKit

class NoteCollectionViewCell: UICollectionViewCell {
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var titleBackgroundView: UIView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var selectedIndicatorView: UIView!
    @IBOutlet weak var selectedImageView: UIImageView!
    @IBOutlet weak var selectedLabel: UILabel!
    @IBOutlet weak var progressView: UIProgressView!
    
    var file: File!
    var url: URL!
        
    override func awakeFromNib() {
        super.awakeFromNib()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    func setFile(url: URL, file: File, isInSelectionMode: Bool = false, isFileSelected: Bool = false, progress: Double? = nil) {
        self.file = file
        self.url = url
        
        self.imageView.layer.cornerRadius = 6
        self.imageView.image = nil
        
        self.selectedIndicatorView.layer.cornerRadius = 4
        
        file.getPreviewImage() { image in
            self.imageView.image = image
        }
        titleLabel.text = file.getName()
        if file is Note {
            self.imageView.backgroundColor = .white
            self.imageView.layer.borderWidth = 1
            self.imageView.layer.borderColor = UIColor.black.cgColor
            if self.traitCollection.userInterfaceStyle == .dark {
                self.imageView.layer.borderColor = UIColor.gray.cgColor
            }
            
        }
        else { // Folder
            self.imageView.backgroundColor = .clear
            self.imageView.layer.borderColor = nil
        }
        self.toggleSelectionModeIndicator(status: isInSelectionMode)
        self.toggleSelected(isFileSelected: isFileSelected)
        
        if let progress = progress {
            progressView.progress = Float(progress)
            progressView.isHidden = false
        }
        else {
            progressView.isHidden = true
        }
    }
    
    func toggleSelected(isFileSelected: Bool) {
        if isFileSelected {
            self.selectedImageView.image = UIImage(systemName: "checkmark.circle.fill")
            self.selectedImageView.tintColor = UIColor.white
            self.selectedLabel.textColor = UIColor.white
            self.selectedLabel.text = "Selected"
            //self.transform = CGAffineTransform(scaleX: 1.0, y: 1.0)
            //self.layer.removeAllAnimations()
            self.selectedIndicatorView.backgroundColor = UIColor.link
        }
        else {
            /*UIView.animate(withDuration: 1,
                           delay: 0,
                           options: [.repeat, .autoreverse, .allowUserInteraction],
                           animations: {
                            self.transform = CGAffineTransform(scaleX: 1.025, y: 1.025)
                            self.layoutIfNeeded()
            }, completion: nil)*/
            self.selectedImageView.image = UIImage(systemName: "checkmark.circle")
            self.selectedLabel.text = "Select"
            self.selectedIndicatorView.backgroundColor = UIColor.darkGray
        }
    }
    
    func toggleSelectionModeIndicator(status: Bool) {
        self.selectedIndicatorView.isHidden = !status
    }
}

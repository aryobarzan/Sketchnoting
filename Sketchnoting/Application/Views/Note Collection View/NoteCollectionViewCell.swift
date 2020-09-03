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
    @IBOutlet weak var selectedImage: UIImageView!
    
    var file: File!
    var url: URL!
        
    override func awakeFromNib() {
        super.awakeFromNib()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    func setFile(url: URL, file: File, isInSelectionMode: Bool = false, isFileSelected: Bool = false) {
        self.file = file
        self.url = url
        
        self.imageView.layer.cornerRadius = 6
        self.imageView.image = nil
        
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
            
    }
    
    func toggleSelected(isFileSelected: Bool) {
        if isFileSelected {
            self.selectedImage.image = UIImage(systemName: "checkmark.circle.fill")
        }
        else {
            self.selectedImage.image = UIImage(systemName: "checkmark.circle")
        }
    }
    
    func toggleSelectionModeIndicator(status: Bool) {
        self.selectedImage.isHidden = !status
    }
}

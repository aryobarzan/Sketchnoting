//
//  NoteCollectionViewDetailCell.swift
//  Sketchnoting
//
//  Created by Aryobarzan on 13/09/2019.
//  Copyright © 2019 Aryobarzan. All rights reserved.
//

import UIKit

class NoteCollectionViewDetailCell: UICollectionViewCell {
    
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var creationLabel: UILabel!
    @IBOutlet weak var selectedImage: UIImageView!
    
    var file: File?
    
    var longPressGesture: UILongPressGestureRecognizer?
    
    override func awakeFromNib() {
        super.awakeFromNib()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    func setFile(file: File, isInSelectionMode: Bool = false, isFileSelected: Bool = false) {
        self.file = file
        
        self.imageView.layer.cornerRadius = 3
        self.imageView.image = nil
        file.getPreviewImage() { image in
            self.imageView.image = image
        }
        if file is Folder {
            self.imageView.backgroundColor = .clear
            self.imageView.layer.borderColor = nil
        }
        else {
            self.imageView.backgroundColor = .white
            self.imageView.layer.borderWidth = 1
            self.imageView.layer.borderColor = UIColor.black.cgColor
            if self.traitCollection.userInterfaceStyle == .dark {
                self.imageView.layer.borderColor = UIColor.gray.cgColor
            }
        }
        
        titleLabel.text = file.getName()
        
        self.creationLabel.text = file.creationDate.getFormattedDate()
        
//        if file is Note {
//            imageView.image = UIImage(systemName: "doc")
//        }
//        else if file is Folder {
//            imageView.image = UIImage(systemName: "folder.fill")
//        }
        if isInSelectionMode {
            self.selectedImage.isHidden = false
            //self.imageView.isHidden = true
        }
        else {
            self.selectedImage.isHidden = true
            //self.imageView.isHidden = false
        }
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
}

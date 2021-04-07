//
//  NoteCollectionViewDetailCell.swift
//  Sketchnoting
//
//  Created by Aryobarzan on 13/09/2019.
//  Copyright © 2019 Aryobarzan. All rights reserved.
//

import UIKit

class NoteCollectionViewDetailCell: UICollectionViewCell, ItemSelectionProtocol {
    
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var creationLabel: UILabel!
    @IBOutlet weak var selectedImageView: UIImageView!
    
    var file: File!
    var url: URL!
    
    var longPressGesture: UILongPressGestureRecognizer?
    
    override func awakeFromNib() {
        super.awakeFromNib()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    override var isSelected: Bool {
      didSet {
        if isSelected {
            selectedImageView.image = UIImage(systemName: "checkmark.circle.fill")
            selectedImageView.tintColor = UIColor.systemBlue
        }
        else {
            selectedImageView.image = UIImage(systemName: "circle")
            selectedImageView.tintColor = UIColor.systemGray
        }
      }
    }
    
    func setFile(url: URL, file: File) {
        self.file = file
        self.url = url
        
        self.imageView.layer.cornerRadius = 3
        self.imageView.image = nil
        file.getPreviewImage() { image in
            self.imageView.image = image
        }
        if file is Note {
            self.imageView.backgroundColor = .white
            self.imageView.layer.borderWidth = 1
            self.imageView.layer.borderColor = UIColor.black.cgColor
            if self.traitCollection.userInterfaceStyle == .dark {
                self.imageView.layer.borderColor = UIColor.gray.cgColor
            }
        }
        else {
            self.imageView.backgroundColor = .clear
            self.imageView.layer.borderColor = nil
        }
        
        titleLabel.text = file.getName()
        
        self.creationLabel.text = NeoLibrary.getCreationDate(url: url).getFormattedDate()
    }
    
    func toggleSelectionMode(status: Bool) {
        selectedImageView.isHidden = !status
    }
}

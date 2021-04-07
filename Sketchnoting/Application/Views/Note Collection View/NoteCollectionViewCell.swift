//
//  NoteCollectionViewCell.swift
//  Sketchnoting
//
//  Created by Aryobarzan on 20/08/2019.
//  Copyright © 2019 Aryobarzan. All rights reserved.
//

import UIKit

class NoteCollectionViewCell: UICollectionViewCell, ItemSelectionProtocol {
    
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var titleBackgroundView: UIView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var selectedImageView: UIImageView!
    @IBOutlet weak var progressView: UIProgressView!
    
    var file: File!
    var url: URL!
        
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
        
    func setFile(url: URL, file: File, progress: Double? = nil) {
        self.file = file
        self.url = url
        
        imageView.layer.cornerRadius = 6
        imageView.image = nil
        selectedImageView.tintColor = UIColor.systemGray

        
        file.getPreviewImage() { image in
            self.imageView.image = image
        }
        titleLabel.text = file.getName()
        if file is Note {
            imageView.backgroundColor = .white
            imageView.layer.borderWidth = 1
            imageView.layer.borderColor = UIColor.black.cgColor
            if traitCollection.userInterfaceStyle == .dark {
                imageView.layer.borderColor = UIColor.gray.cgColor
            }
            
        }
        else { // Folder
            imageView.backgroundColor = .clear
            imageView.layer.borderColor = nil
        }
        
        if let progress = progress {
            progressView.progress = Float(progress)
            progressView.isHidden = false
        }
        else {
            progressView.isHidden = true
        }
    }
    
    func toggleSelectionMode(status: Bool) {
        selectedImageView.isHidden = !status
    }
}

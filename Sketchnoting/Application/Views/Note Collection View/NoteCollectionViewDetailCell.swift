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
        
        titleLabel.text = file.getName()
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        
        let dateAsString = formatter.string(from: file.creationDate)
        let date = formatter.date(from: dateAsString)
        formatter.dateFormat = "dd MMM yyyy (HH:mm)"
        let formattedDateAsString = formatter.string(from: date!)
        self.creationLabel.text = formattedDateAsString
        
        if file is Note {
            imageView.image = UIImage(systemName: "doc")
        }
        else if file is Folder {
            imageView.image = UIImage(systemName: "folder.fill")
        }
        if isInSelectionMode {
            self.selectedImage.isHidden = false
            self.imageView.isHidden = true
        }
        else {
            self.selectedImage.isHidden = true
            self.imageView.isHidden = false
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

//
//  FolderCollectionViewCell.swift
//  Sketchnoting
//
//  Created by Aryobarzan on 07/04/2021.
//  Copyright © 2021 Aryobarzan. All rights reserved.
//

import UIKit

class FolderCollectionViewCell: UICollectionViewCell, ItemSelectionProtocol {
    
    @IBOutlet weak var folderImageView: UIImageView!
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var subtitleLabel: UILabel!
    @IBOutlet weak var selectionImageView: UIImageView!
    
    var url: URL!
    var file: File!
        
    override func awakeFromNib() {
        super.awakeFromNib()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    override var isSelected: Bool {
      didSet {
        if isSelected {
            self.selectionImageView.image = UIImage(systemName: "checkmark.circle.fill")
        }
        else {
            self.selectionImageView.image = UIImage(systemName: "circle")
        }
      }
    }
    
    func setFile(url: URL, file: File) {
        self.file = file
        self.url = url
        
        self.layer.cornerRadius = 16

        nameLabel.text = file.getName()
        let folderItemsCount = NeoLibrary.getFolderItemsCount(url: url)
        subtitleLabel.text = folderItemsCount == 0 ? "Empty." : "\(folderItemsCount) files."
    }
    
    func toggleSelectionMode(status: Bool) {
        selectionImageView.isHidden = !status
    }
}

//
//  TagTableViewCell.swift
//  Sketchnoting
//
//  Created by Kael on 12/09/2019.
//  Copyright © 2019 Aryobarzan. All rights reserved.
//

import UIKit

class TagTableViewCell: UITableViewCell {

    @IBOutlet weak var colorView: UIImageView!
    @IBOutlet weak var titleLabel: UILabel!
    
    var noteTag: Tag?
    
    override func awakeFromNib() {
        super.awakeFromNib()
    }
    
    public func setTag(tag: Tag) {
        self.noteTag = tag
        
        titleLabel.text = noteTag?.title
        colorView.tintColor = noteTag?.color
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }
}

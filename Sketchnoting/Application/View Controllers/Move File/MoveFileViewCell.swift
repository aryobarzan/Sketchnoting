//
//  MoveFileViewCell.swift
//  Sketchnoting
//
//  Created by Aryobarzan on 02/06/2020.
//  Copyright © 2020 Aryobarzan. All rights reserved.
//

import UIKit

class MoveFileViewCell: UITableViewCell {
    
    var folderURL: URL!
    @IBOutlet weak var nameLabel: UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }
    
    public func set(folderURL: URL) {
        self.folderURL = folderURL
        
        nameLabel.text = folderURL.deletingPathExtension().lastPathComponent
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
    }

}

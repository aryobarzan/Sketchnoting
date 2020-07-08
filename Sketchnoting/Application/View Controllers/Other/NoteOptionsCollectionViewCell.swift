//
//  NoteOptionsCollectionViewCell.swift
//  Sketchnoting
//
//  Created by Aryobarzan on 28/06/2020.
//  Copyright © 2020 Aryobarzan. All rights reserved.
//

import UIKit

class NoteOptionsCollectionViewCell: UICollectionViewCell {
    
    @IBOutlet weak var label: UILabel!
    @IBOutlet weak var image: UIImageView!
    @IBOutlet weak var notInstantActionImage: UIImageView!
        
    func set(option: NoteOptionWrapper) {
        if option.option == .HelpLines {
            image.image = UIImage(systemName: "grid")
        }
        else {
            image.image = UIImage(systemName: option.image)
        }
        image.layer.cornerRadius = 4
        if option.isDestructive {
            image.backgroundColor = .systemRed
        }
        else {
            image.backgroundColor = .link
        }
        notInstantActionImage.isHidden = option.isInstantAction
        
        label.text = option.option.rawValue
    }
}

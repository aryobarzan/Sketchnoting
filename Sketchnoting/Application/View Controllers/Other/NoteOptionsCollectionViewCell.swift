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
            switch DataManager.activeNote!.helpLinesType {
            case .None:
                image.image = UIImage(systemName: "perspective")
                break
            case .Horizontal:
                image.image = UIImage(systemName: "line.horizontal.3")
                break
            case .Grid:
                image.image = UIImage(systemName: "grid")
                break
            }
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

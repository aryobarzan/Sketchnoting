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
    @IBOutlet weak var moreButton: UIButton!
    @IBOutlet weak var creationDateLabel: UILabel!
    @IBOutlet weak var creationDateBackgroundView: UIView!
    
    var delegate : NoteCollectionViewCellDelegate!
    
    var sketchnote: Sketchnote!
    
    override func awakeFromNib() {
        super.awakeFromNib()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    func setNote(note: Sketchnote) {
        self.layer.borderWidth = 1
        self.layer.borderColor = UIColor.black.cgColor
        creationDateBackgroundView.layer.cornerRadius = 18
        
        sketchnote = note
        imageView.image = sketchnote.image
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let dateAsString = formatter.string(from: sketchnote.creationDate)
        let date = formatter.date(from: dateAsString)
        formatter.dateFormat = "dd MMM yyyy"
        let formattedDateAsString = formatter.string(from: date!)
        self.creationDateLabel.text = formattedDateAsString
    }
    
    
    @IBAction func moreButtonTapped(_ sender: UIButton) {
        delegate.noteCollectionViewCellMoreTapped(sketchnote: sketchnote, sender: self)
    }
}
protocol NoteCollectionViewCellDelegate {
    func noteCollectionViewCellMoreTapped(sketchnote: Sketchnote, sender: NoteCollectionViewCell)
}

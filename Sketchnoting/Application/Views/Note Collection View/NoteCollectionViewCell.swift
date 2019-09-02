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
    @IBOutlet weak var titleBackgroundView: UIView!
    @IBOutlet weak var titleLabel: UILabel!
    
    var delegate : NoteCollectionViewCellDelegate!
    
    var sketchnote: Sketchnote!
    
    var longPressGesture: UILongPressGestureRecognizer?
    
    override func awakeFromNib() {
        super.awakeFromNib()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    func setNote(note: Sketchnote) {
        //self.layer.borderWidth = 1
        //self.layer.borderColor = UIColor.black.cgColor
        //creationDateBackgroundView.layer.cornerRadius = 18
        //documentsBackgroundView.layer.cornerRadius = 18
        //titleBackgroundView.layer.cornerRadius = 18
        imageView.layer.borderWidth = 1
        imageView.layer.borderColor = UIColor.black.cgColor
        
        sketchnote = note
        imageView.image = sketchnote.image
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let dateAsString = formatter.string(from: sketchnote.creationDate)
        let date = formatter.date(from: dateAsString)
        formatter.dateFormat = "dd MMM yyyy"
        let formattedDateAsString = formatter.string(from: date!)
        self.creationDateLabel.text = formattedDateAsString
        
        titleLabel.text = note.getTitle()
        
        if longPressGesture == nil {
            longPressGesture = UILongPressGestureRecognizer(target: self, action: #selector(self.longPressed(_:)))
            self.addGestureRecognizer(longPressGesture!)
        }
        
    }
    
    @objc func longPressed(_ sender: UILongPressGestureRecognizer) {
        self.moreButtonTrigger()
    }
    
    @IBAction func moreButtonTapped(_ sender: UIButton) {
        self.moreButtonTrigger()
    }
    
    private func moreButtonTrigger() {
        delegate.noteCollectionViewCellMoreTapped(sketchnote: sketchnote, sender: self)
    }
}
protocol NoteCollectionViewCellDelegate {
    func noteCollectionViewCellMoreTapped(sketchnote: Sketchnote, sender: NoteCollectionViewCell)
}

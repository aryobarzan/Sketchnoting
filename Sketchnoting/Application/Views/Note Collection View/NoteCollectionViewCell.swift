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
    @IBOutlet weak var titleBackgroundView: UIView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var shareButton: UIButton!
    @IBOutlet weak var moreButton: UIButton!
    
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
        self.layer.borderWidth = 1
        self.layer.borderColor = UIColor.black.cgColor
        self.layer.cornerRadius = 4
        
        sketchnote = note
        imageView.image = sketchnote.image
        
        titleLabel.text = note.getTitle()
        
        if longPressGesture == nil {
            longPressGesture = UILongPressGestureRecognizer(target: self, action: #selector(self.longPressed(_:)))
            self.addGestureRecognizer(longPressGesture!)
        }
    }
    
    @objc func longPressed(_ sender: UILongPressGestureRecognizer) {
        delegate.noteCollectionViewCellLongPressed(sketchnote: sketchnote, sender: sender, cell: self)
    }
    
    @IBAction func shareTapped(_ sender: UIButton) {
        delegate.noteCollectionViewCellShareTapped(sketchnote: sketchnote, sender: sender, cell: self)
    }
    @IBAction func moreTapped(_ sender: UIButton) {
        delegate.noteCollectionViewCellMoreTapped(sketchnote: sketchnote, sender: moreButton, cell: self)
    }
}
protocol NoteCollectionViewCellDelegate {
    func noteCollectionViewCellMoreTapped(sketchnote: Sketchnote, sender: UIButton, cell: NoteCollectionViewCell)
    func noteCollectionViewCellShareTapped(sketchnote: Sketchnote, sender: UIButton, cell: NoteCollectionViewCell)
    func noteCollectionViewCellLongPressed(sketchnote: Sketchnote, sender: UILongPressGestureRecognizer, cell: NoteCollectionViewCell)
}

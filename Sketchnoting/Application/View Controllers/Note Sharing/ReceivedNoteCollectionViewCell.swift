//
//  ReceivedNoteCollectionViewCell.swift
//  Sketchnoting
//
//  Created by Aryobarzan on 05/02/2020.
//  Copyright © 2020 Aryobarzan. All rights reserved.
//

import UIKit

class ReceivedNoteCollectionViewCell: UICollectionViewCell {
    
    @IBOutlet var imageView: UIImageView!
    @IBOutlet var grabButton: UIButton!
    @IBOutlet var rejectButton: UIButton!
    @IBOutlet var noteTitleLabel: UILabel!
    @IBOutlet var senderLabel: UILabel!
    
    var delegate: ReceivedNoteCellDelegate?
    
    var note: Sketchnote!
    override func awakeFromNib() {
        super.awakeFromNib()
    }
    required init?(coder aDecoder: NSCoder) {
           super.init(coder: aDecoder)
    }
       
    func setNote(note: Sketchnote) {
        self.note = note
           
        imageView.image = note.getPreviewImage()
        imageView.layer.borderColor = UIColor.gray.cgColor
        imageView.layer.borderWidth = 1
        noteTitleLabel.text = note.getTitle()
        senderLabel.text = note.sharedByDevice
        
        grabButton.layer.cornerRadius = 17
        rejectButton.layer.cornerRadius = 17
    }
    @IBAction func grabTapped(_ sender: UIButton) {
        delegate?.acceptReceivedNote(note: note)
    }
    @IBAction func rejectTapped(_ sender: UIButton) {
        delegate?.rejectReceivedNote(note: note)
    }
}

protocol ReceivedNoteCellDelegate {
    func acceptReceivedNote(note: Sketchnote)
    func rejectReceivedNote(note: Sketchnote)
}

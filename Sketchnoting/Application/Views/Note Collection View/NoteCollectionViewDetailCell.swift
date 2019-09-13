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
    @IBOutlet weak var titlelabel: UILabel!
    @IBOutlet weak var creationLabel: UILabel!
    @IBOutlet weak var updatedLabel: UILabel!
    @IBOutlet weak var documentsLabel: UILabel!
    @IBOutlet weak var tagsLabel: UILabel!
    @IBOutlet weak var editTitleButton: UIButton!
    @IBOutlet weak var editTagsButton: UIButton!
    @IBOutlet weak var shareButton: UIButton!
    @IBOutlet weak var sendButton: UIButton!
    @IBOutlet weak var copyTextButton: UIButton!
    @IBOutlet weak var deleteButton: UIButton!
    
    var delegate : NoteCollectionViewDetailCellDelegate!
    var commonDelegate: NoteCollectionViewCellCommonDelegate!
    
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
        imageView.layer.masksToBounds = true
        imageView.layer.borderColor = UIColor.black.cgColor
        imageView.layer.borderWidth = 1
        
        titlelabel.text = note.getTitle()
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        
        let dateAsString = formatter.string(from: sketchnote.creationDate)
        let date = formatter.date(from: dateAsString)
        formatter.dateFormat = "dd MMM yyyy"
        let formattedDateAsString = formatter.string(from: date!)
        self.creationLabel.text = "Created: " + formattedDateAsString
        
        if let updateDate = sketchnote.updateDate {
            let dateAsString = formatter.string(from: updateDate)
            let date = formatter.date(from: dateAsString)
            formatter.dateFormat = "dd MMM yyyy"
            let formattedDateAsString = formatter.string(from: date!)
            self.updatedLabel.text = "Updated: " + formattedDateAsString
        }
        else {
            self.updatedLabel.text = "Updated: Never"
        }
        
        if sketchnote.tags.count > 0 {
            self.tagsLabel.text = "Tags: "
            for tag in sketchnote.tags {
                self.tagsLabel.text = self.tagsLabel.text! + tag.title + " · "
            }
        }
        else {
             self.tagsLabel.text = "No tags"
        }
        
        if sketchnote.documents.count > 0 {
            self.documentsLabel.text = "\(sketchnote.documents.count) Documents"
        }
        else {
            self.documentsLabel.text = ""
        }

        
        if longPressGesture == nil {
            longPressGesture = UILongPressGestureRecognizer(target: self, action: #selector(self.longPressed(_:)))
            self.addGestureRecognizer(longPressGesture!)
        }
    }
    
    @objc func longPressed(_ sender: UILongPressGestureRecognizer) {
        switch sender.state {
        case .began:
            commonDelegate.noteCollectionViewCellLongPressed(sketchnote: sketchnote, status: true)
        case .ended:
            commonDelegate.noteCollectionViewCellLongPressed(sketchnote: sketchnote, status: false)
        case .cancelled:
            commonDelegate.noteCollectionViewCellLongPressed(sketchnote: sketchnote, status: false)
        case .failed:
            commonDelegate.noteCollectionViewCellLongPressed(sketchnote: sketchnote, status: false)
        default:
            break
        }
    }
    
    @IBAction func editTitleTapped(_ sender: UIButton) {
        delegate.noteCollectionViewDetailCellEditTitleTapped(sketchnote: sketchnote, sender: sender, cell: self)
    }
    @IBAction func tagTapped(_ sender: UIButton) {
        commonDelegate.noteCollectionViewCellTagTapped(sketchnote: sketchnote)
    }
    @IBAction func shareTapped(_ sender: UIButton) {
        delegate.noteCollectionViewDetailCellShareTapped(sketchnote: sketchnote, sender: sender, cell: self)
    }
    @IBAction func sendTapped(_ sender: UIButton) {
        delegate.noteCollectionViewDetailCellSendTapped(sketchnote: sketchnote, sender: sender, cell: self)
    }
    @IBAction func copyTextTapped(_ sender: UIButton) {
        delegate.noteCollectionViewDetailCellCopyTextTapped(sketchnote: sketchnote, sender: sender, cell: self)
    }
    @IBAction func deleteTapped(_ sender: UIButton) {
        delegate.noteCollectionViewDetailCellDeleteTapped(sketchnote: sketchnote, sender: sender, cell: self)
    }
}

protocol NoteCollectionViewDetailCellDelegate {
    func noteCollectionViewDetailCellEditTitleTapped(sketchnote: Sketchnote, sender: UIButton, cell: NoteCollectionViewDetailCell)
    func noteCollectionViewDetailCellShareTapped(sketchnote: Sketchnote, sender: UIButton, cell: NoteCollectionViewDetailCell)
    func noteCollectionViewDetailCellSendTapped(sketchnote: Sketchnote, sender: UIButton, cell: NoteCollectionViewDetailCell)
    func noteCollectionViewDetailCellCopyTextTapped(sketchnote: Sketchnote, sender: UIButton, cell: NoteCollectionViewDetailCell)
    func noteCollectionViewDetailCellDeleteTapped(sketchnote: Sketchnote, sender: UIButton, cell: NoteCollectionViewDetailCell)
}


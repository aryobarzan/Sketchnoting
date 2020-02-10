//
//  NoteCollectionViewDetailCell.swift
//  Sketchnoting
//
//  Created by Aryobarzan on 13/09/2019.
//  Copyright © 2019 Aryobarzan. All rights reserved.
//

import UIKit
import UICircularProgressRing

class NoteCollectionViewDetailCell: UICollectionViewCell {
    
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var creationLabel: UILabel!
    @IBOutlet weak var updatedLabel: UILabel!
    @IBOutlet weak var tagsLabel: UILabel!
    @IBOutlet weak var editTitleButton: UIButton!
    @IBOutlet weak var editTagsButton: UIButton!
    @IBOutlet weak var shareButton: UIButton!
    @IBOutlet weak var sendButton: UIButton!
    @IBOutlet weak var copyTextButton: UIButton!
    @IBOutlet weak var deleteButton: UIButton!
    @IBOutlet weak var similarityWeightProgressRing: UICircularProgressRing!
    
    var delegate : NoteCollectionViewDetailCellDelegate!
    
    var file: File?
    
    var longPressGesture: UILongPressGestureRecognizer?
    
    override func awakeFromNib() {
        super.awakeFromNib()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    func setFile(file: File) {
        self.file = file
        
        titleLabel.text = file.getName()
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        
        let dateAsString = formatter.string(from: file.creationDate)
        let date = formatter.date(from: dateAsString)
        formatter.dateFormat = "dd MMM yyyy"
        let formattedDateAsString = formatter.string(from: date!)
        self.creationLabel.text = "Created: " + formattedDateAsString
        
        let updateDateAsString = formatter.string(from: file.updateDate)
        let updateDate = formatter.date(from: updateDateAsString)
        formatter.dateFormat = "dd MMM yyyy"
        let formattedupdateDateAsString = formatter.string(from: updateDate!)
        self.updatedLabel.text = "Updated: " + formattedupdateDateAsString
        
        self.tagsLabel.text = ""
        self.editTagsButton.isHidden = true
        self.shareButton.isHidden = true
        self.sendButton.isHidden = true
        self.copyTextButton.isHidden = true
        if let note = file as? NoteX {
            if note.tags.count > 0 {
                self.tagsLabel.text = ""
                for tag in note.tags {
                    self.tagsLabel.text = self.tagsLabel.text! + tag.title + " · "
                }
            }
            self.editTagsButton.isHidden = false
            self.shareButton.isHidden = false
            self.sendButton.isHidden = false
            self.copyTextButton.isHidden = false
        }
        similarityWeightProgressRing.isHidden = true
    }
    
    func showSimilarityRing(weight: Double, max: Double) {
        similarityWeightProgressRing.maxValue = CGFloat(max)
        similarityWeightProgressRing.value = CGFloat(weight)
        similarityWeightProgressRing.isHidden = false
    }
    
    @IBAction func renameTapped(_ sender: UIButton) {
        delegate.noteCollectionViewDetailCellRenameTapped(file: file!, sender: sender, cell: self)
    }
    @IBAction func tagTapped(_ sender: UIButton) {
        delegate.noteCollectionViewDetailCellTagTapped(note: file! as! NoteX, sender: sender, cell: self)
    }
    @IBAction func shareTapped(_ sender: UIButton) {
        delegate.noteCollectionViewDetailCellShareTapped(note: file! as! NoteX, sender: sender, cell: self)
    }
    @IBAction func sendTapped(_ sender: UIButton) {
        delegate.noteCollectionViewDetailCellSendTapped(note: file! as! NoteX, sender: sender, cell: self)
    }
    @IBAction func copyTextTapped(_ sender: UIButton) {
        delegate.noteCollectionViewDetailCellCopyTextTapped(note: file! as! NoteX, sender: sender, cell: self)
    }
    @IBAction func deleteTapped(_ sender: UIButton) {
        delegate.noteCollectionViewDetailCellDeleteTapped(file: file!, sender: sender, cell: self)
    }
}

protocol NoteCollectionViewDetailCellDelegate {
    func noteCollectionViewDetailCellRenameTapped(file: File, sender: UIButton, cell: NoteCollectionViewDetailCell)
    func noteCollectionViewDetailCellTagTapped(note: NoteX, sender: UIButton, cell: NoteCollectionViewDetailCell)
    func noteCollectionViewDetailCellShareTapped(note: NoteX, sender: UIButton, cell: NoteCollectionViewDetailCell)
    func noteCollectionViewDetailCellSendTapped(note: NoteX, sender: UIButton, cell: NoteCollectionViewDetailCell)
    func noteCollectionViewDetailCellCopyTextTapped(note: NoteX, sender: UIButton, cell: NoteCollectionViewDetailCell)
    func noteCollectionViewDetailCellDeleteTapped(file: File, sender: UIButton, cell: NoteCollectionViewDetailCell)
}


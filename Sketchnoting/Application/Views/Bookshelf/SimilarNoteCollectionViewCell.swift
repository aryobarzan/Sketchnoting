//
//  SimilarNoteCollectionViewCell.swift
//  Sketchnoting
//
//  Created by Aryobarzan on 15/11/2019.
//  Copyright © 2019 Aryobarzan. All rights reserved.
//

import UIKit

class SimilarNoteCollectionViewCell: UICollectionViewCell {

    @IBOutlet var previewImageView: UIImageView!
    @IBOutlet var titleLabel: UILabel!
    @IBOutlet var noteTextView: UITextView!
    @IBOutlet var documentsTextView: UITextView!
    @IBOutlet var similarityRatingLabel: UILabel!
    
    var sketchnote: Sketchnote!
    override func awakeFromNib() {
        super.awakeFromNib()
    }
    required init?(coder aDecoder: NSCoder) {
           super.init(coder: aDecoder)
    }
       
    func setNote(note: Sketchnote, similarityRating: Double) {
        sketchnote = note
           
        titleLabel.text = note.getTitle()
        noteTextView.text = note.getText().trimmingCharacters(in: .whitespaces)
        previewImageView.image = note.getPreviewImage()
        similarityRatingLabel.text = "Similarity Rating: \(similarityRating)"
        
        var documentsText = "Documents: "
        for i in 0...note.documents.count-1 {
            if i == note.documents.count-1 {
                documentsText += note.documents[i].title
            }
            else {
                documentsText += note.documents[i].title + " · "
            }
        }
        documentsTextView.text = documentsText
        
        self.layer.borderWidth = 1
        self.layer.borderColor = UIColor.white.cgColor
        self.layer.cornerRadius = 4
        
        self.previewImageView.layer.cornerRadius = 2
    }
}

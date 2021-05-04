//
//  DocumentCollectionViewCell.swift
//  Sketchnoting
//
//  Created by Aryobarzan on 04/05/2021.
//  Copyright © 2021 Aryobarzan. All rights reserved.
//

import UIKit

class DocumentCollectionViewCell: UICollectionViewCell {

    @IBOutlet weak var previewImageView: UIImageView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var progressView: CircularProgressView!
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }
    
    var document: Document? {
      didSet {
        previewImageView.image = UIImage(systemName: "questionmark.circle.fill")
        if let document = document {
            document.retrieveImage(type: .Standard, completion: { result in
                switch result {
                case .success(let value):
                    if let value = value {
                        DispatchQueue.main.async {
                            self.previewImageView.image = value
                        }
                    }
                    else {
                        // log.error("Failed to load in preview image for document: \(document.title)")
                        // log.error(result)
                    }
                case .failure(let error):
                    logger.error(error)
                    logger.error("No preview image found for document: \(document.title).")
                }
            })
        }
        previewImageView.layer.cornerRadius = 75
        titleLabel.text = document?.title
      }
    }
    
    var score: Double? {
        didSet {
            if let score = score {
                progressView.progress = Float(score)
                progressView.isHidden = false
            }
            else {
                progressView.isHidden = true
            }
        }
    }
}

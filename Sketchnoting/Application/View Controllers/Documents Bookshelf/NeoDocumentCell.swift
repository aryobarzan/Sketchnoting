//
//  NeoDocumentCell.swift
//  Sketchnoting
//
//  Created by Aryobarzan on 20/07/2020.
//  Copyright © 2020 Aryobarzan. All rights reserved.
//

import UIKit

class NeoDocumentCell: UICollectionViewCell {
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var titleLabel: UILabel!
    var document: Document? {
      didSet {
        imageView.image = UIImage(systemName: "questionmark.circle.fill")
        if let document = document {
            document.retrieveImage(type: .Standard, completion: { result in
                switch result {
                case .success(let value):
                    if let value = value {
                        DispatchQueue.main.async {
                            self.imageView.image = value
                        }
                    }
                    else {
                        log.error("Failed to load in preview image for document: \(document.title)")
                        log.error(result)
                    }
                case .failure(let error):
                    log.error(error)
                    log.error("No preview image found for document: \(document.title).")
                }
            })
        }
        
        imageView.layer.cornerRadius = 75
        titleLabel.text = document?.title
      }
    }
}

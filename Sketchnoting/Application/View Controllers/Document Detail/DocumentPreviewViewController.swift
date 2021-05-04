//
//  DocumentPreviewViewController.swift
//  Sketchnoting
//
//  Created by Aryobarzan on 06/02/2020.
//  Copyright © 2020 Aryobarzan. All rights reserved.
//

import UIKit

class DocumentPreviewViewController: UIViewController {

    @IBOutlet var imageView: UIImageView!
    @IBOutlet var titleLabel: UILabel!
    @IBOutlet var bodyTextView: UITextView!
    override func viewDidLoad() {
        super.viewDidLoad()
        
        imageView.layer.cornerRadius = 50
    }
    var document: Document? {
        didSet {
            if let document = document {
                document.retrieveImage(type: .Standard, completion: { result in
                    switch result {
                    case .success(let value):
                        if let value = value {
                            DispatchQueue.main.async {
                                self.imageView.image = value
                            }
                        }
                    case .failure(_):
                        logger.error("No preview image found for document.")
                    }
                })
                self.titleLabel.text = document.title
                self.bodyTextView.text = document.getDescription()
                bodyTextView.dataDetectorTypes = UIDataDetectorTypes.link
            }
        }
    }
}

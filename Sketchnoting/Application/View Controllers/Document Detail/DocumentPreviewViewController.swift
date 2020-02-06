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
}

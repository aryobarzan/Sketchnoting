//
//  SimpleTextViewController.swift
//  Sketchnoting
//
//  Created by Aryobarzan on 26/05/2021.
//  Copyright © 2021 Aryobarzan. All rights reserved.
//

import UIKit

class SimpleTextViewController: UIViewController {

    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var bodyTextView: UITextView!
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    var titleText: String = "" {
        didSet {
            titleLabel.text = titleText
        }
    }
    var bodyText: String = "" {
        didSet {
            bodyTextView.text = bodyText
        }
    }
}

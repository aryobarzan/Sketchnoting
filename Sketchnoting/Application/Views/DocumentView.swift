//
//  DocumentView.swift
//  Sketchnoting
//
//  Created by Aryobarzan on 13/03/2019.
//  Copyright © 2019 Aryobarzan. All rights reserved.
//

import UIKit
import LGButton

// This is the view used for displaying a single related document

class DocumentView: UIView {
    let kCONTENT_XIB_NAME = "DocumentView"
    
    @IBOutlet var contentView: UIView!
    @IBOutlet var titleLabel: UILabel!
    @IBOutlet var viewButton: LGButton!
    @IBOutlet var descriptionLabel: UILabel!
    @IBOutlet var bottomLine: UIView!
    
    var urlString: String?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        commonInit()
    }
    
    func commonInit() {
        Bundle.main.loadNibNamed(kCONTENT_XIB_NAME, owner: self, options: nil)
        contentView.fixInView(self)
        self.widthAnchor.constraint(equalToConstant: 400).isActive = true
        self.heightAnchor.constraint(equalToConstant: 280).isActive = true
    }
    @IBAction func viewTapped(_ sender: LGButton) {
        guard let url = URL(string: urlString ?? "") else { return }
        UIApplication.shared.open(url)
    }
}

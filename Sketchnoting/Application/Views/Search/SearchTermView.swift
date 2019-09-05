//
//  SearchTermView.swift
//  Sketchnoting
//
//  Created by Aryobarzan on 05/09/2019.
//  Copyright © 2019 Aryobarzan. All rights reserved.
//

import UIKit

class SearchTermView: UIView {
    let kCONTENT_XIB_NAME = "SearchTermView"
    
    var delegate: SearchTermViewDelegate?
    
    @IBOutlet weak var contentView: SearchTermView!
    @IBOutlet weak var closeButtonView: UIView!
    @IBOutlet weak var closeButton: UIButton!
    @IBOutlet weak var mainLabel: UILabel!
    @IBOutlet weak var subLabel: UILabel!
    
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
        //self.widthAnchor.constraint(equalToConstant: 490).isActive = true
        //self.heightAnchor.constraint(equalToConstant: 600).isActive = true
    }
    
    func setContent(term: String, type: SearchType) {
        mainLabel.text = term
        
        subLabel.text = type.rawValue
    }
    
    
    @IBAction func closeButtonTapped(_ sender: UIButton) {
        delegate?.closeSearchTermTapped(sender: self)
    }
}
protocol SearchTermViewDelegate {
    func closeSearchTermTapped(sender: SearchTermView)
}

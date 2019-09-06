//
//  SearchTermView.swift
//  Sketchnoting
//
//  Created by Aryobarzan on 05/09/2019.
//  Copyright © 2019 Aryobarzan. All rights reserved.
//

import UIKit

class SearchFilterView: UIView {
    let kCONTENT_XIB_NAME = "SearchFilterView"
        
    @IBOutlet var contentView: UIView!
    @IBOutlet var closeButtonView: UIView!
    @IBOutlet var closeButton: UIButton!
    @IBOutlet var mainLabel: UILabel!
    @IBOutlet var subLabel: UILabel!
    
    var searchFilter: SearchFilter?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        commonInit()
    }
    
    public init(filter: SearchFilter) {
        super.init(frame: CGRect.zero)
        Bundle.main.loadNibNamed(kCONTENT_XIB_NAME, owner: self, options: nil)
        contentView.fixInView(self)
        self.backgroundColor = tintColor
        self.layer.cornerRadius = cornerRadius
        self.layer.masksToBounds = true
        
        self.closeButtonView.layer.cornerRadius = 15
        self.closeButtonView.layer.masksToBounds = true
        
        setContent(filter: filter)
        setNeedsLayout()
        self.closeButtonView.setNeedsLayout()
    }
    
    func commonInit() {
        Bundle.main.loadNibNamed(kCONTENT_XIB_NAME, owner: self, options: nil)
        contentView.fixInView(self)
    }
    
    open var cornerRadius: CGFloat = 5.0 {
        didSet {
            self.layer.cornerRadius = cornerRadius
            setNeedsDisplay()
        }
    }
    
    
    func setContent(filter: SearchFilter) {
        self.searchFilter = filter
        mainLabel.text = filter.term
        subLabel.text = filter.type.rawValue
    }
}

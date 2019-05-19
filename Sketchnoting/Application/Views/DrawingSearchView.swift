//
//  DrawingSearchView.swift
//  Sketchnoting
//
//  Created by Aryobarzan on 09/04/2019.
//  Copyright © 2019 Aryobarzan. All rights reserved.
//

import UIKit
import LGButton

// This is the view displayed as a pop up when the user wants to search by drawing (button located on the home page)

class DrawingSearchView: UIView {
    let kCONTENT_XIB_NAME = "DrawingSearchView"
    
    @IBOutlet var contentView: UIView!
    @IBOutlet var clearButton: LGButton!
    @IBOutlet var closeButton: LGButton!
    @IBOutlet var searchButton: LGButton!
    @IBOutlet var sketchView: SketchView!
    
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
        self.widthAnchor.constraint(equalToConstant: 490).isActive = true
        self.heightAnchor.constraint(equalToConstant: 600).isActive = true
        contentView.fixInView(self)
        
        sketchView.backgroundColor = .black
        sketchView.drawTool = .pen
        sketchView.lineColor = .white
        sketchView.lineWidth = 490 * 0.04
    }
    
    func setCloseAction(for controlEvents: UIControl.Event, _ closure: @escaping ()->()) {
        let sleeve = ClosureSleeve(closure)
        closeButton.addTarget(sleeve, action: #selector(ClosureSleeve.invoke), for: controlEvents)
        objc_setAssociatedObject(self, String(format: "[%d]", arc4random()), sleeve, objc_AssociationPolicy.OBJC_ASSOCIATION_RETAIN)
    }
    func setSearchAction(for controlEvents: UIControl.Event, _ closure: @escaping ()->()) {
        let sleeve = ClosureSleeve(closure)
        searchButton.addTarget(sleeve, action: #selector(ClosureSleeve.invoke), for: controlEvents)
        objc_setAssociatedObject(self, String(format: "[%d]", arc4random()), sleeve, objc_AssociationPolicy.OBJC_ASSOCIATION_RETAIN)
    }
    @IBAction func clearTapped(_ sender: LGButton) {
        sketchView.clear()
    }
}

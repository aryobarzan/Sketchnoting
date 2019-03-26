//
//  SketchnoteView.swift
//  Sketchnoting
//
//  Created by Aryobarzan on 25/03/2019.
//  Copyright © 2019 Aryobarzan. All rights reserved.
//

import UIKit

class SketchnoteView : UIView {
    let kCONTENT_XIB_NAME = "SketchnoteView"
    @IBOutlet var contentView: UIView!
    @IBOutlet var imageView: UIImageView!
    
    var sketchnote: Sketchnote?
    
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
        self.widthAnchor.constraint(equalToConstant: 200).isActive = true
        //self.heightAnchor.constraint(equalToConstant: 300).isActive = true
        contentView.fixInView(self)
        
    }
    
    func setNote(note: Sketchnote) {
        self.sketchnote = note
        self.imageView.image = note.image
    }
}

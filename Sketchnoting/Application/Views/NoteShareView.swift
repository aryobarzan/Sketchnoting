//
//  NoteShareView.swift
//  Sketchnoting
//
//  Created by Aryobarzan on 17/04/2019.
//  Copyright © 2019 Aryobarzan. All rights reserved.
//

import UIKit
import LGButton

// This is the view displayed to a recipient of a shared note
// It displays a preview of the received note and lets the receiver reject or accept the shared note

class NoteShareView: UIView {
    let kCONTENT_XIB_NAME = "NoteShareView"
    
    @IBOutlet var contentView: UIView!
    @IBOutlet var senderLabel: UILabel!
    @IBOutlet var sketchnoteView: SketchnoteView!
    @IBOutlet var rejectButton: LGButton!
    @IBOutlet var acceptButton: LGButton!
    @IBOutlet var closeButton: LGButton!
    
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
        self.widthAnchor.constraint(equalToConstant: 326).isActive = true
        self.heightAnchor.constraint(equalToConstant: 435).isActive = true
        contentView.fixInView(self)
        
        self.layer.borderWidth = 1
        self.layer.borderColor = UIColor.black.cgColor
    }
    
    func setRejectAction(_ closure: @escaping ()->()) {
        let sleeve = ClosureSleeve(closure)
        rejectButton.addTarget(sleeve, action: #selector(ClosureSleeve.invoke), for: .touchUpInside)
        objc_setAssociatedObject(self, String(format: "[%d]", arc4random()), sleeve, objc_AssociationPolicy.OBJC_ASSOCIATION_RETAIN)
    }
    func setAcceptAction(_ closure: @escaping ()->()) {
        let sleeve = ClosureSleeve(closure)
        acceptButton.addTarget(sleeve, action: #selector(ClosureSleeve.invoke), for: .touchUpInside)
        objc_setAssociatedObject(self, String(format: "[%d]", arc4random()), sleeve, objc_AssociationPolicy.OBJC_ASSOCIATION_RETAIN)
    }
    func setCloseAction(_ closure: @escaping ()->()) {
        let sleeve = ClosureSleeve(closure)
        closeButton.addTarget(sleeve, action: #selector(ClosureSleeve.invoke), for: .touchUpInside)
        objc_setAssociatedObject(self, String(format: "[%d]", arc4random()), sleeve, objc_AssociationPolicy.OBJC_ASSOCIATION_RETAIN)
    }
}

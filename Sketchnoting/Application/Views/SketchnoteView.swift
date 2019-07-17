//
//  SketchnoteView.swift
//  Sketchnoting
//
//  Created by Aryobarzan on 25/03/2019.
//  Copyright © 2019 Aryobarzan. All rights reserved.
//

import UIKit

// This is the corresponding controller for the SketchnoteView.xib
// This view displays a single note with its preview image

class SketchnoteView : UIView {
    let kCONTENT_XIB_NAME = "SketchnoteView"
    @IBOutlet var contentView: UIView!
    @IBOutlet var imageView: UIImageView!
    @IBOutlet var creationDateView: UIView!
    @IBOutlet var creationDateLabel: UILabel!
    
    var sketchnote: Sketchnote?
    
    var matchesSearch = true
    
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
        contentView.fixInView(self)
        
        self.layer.borderWidth = 1
        self.layer.borderColor = UIColor.black.cgColor
        creationDateView.layer.cornerRadius = 12
    }
    
    func setNote(note: Sketchnote) {
        self.sketchnote = note
        self.imageView.image = note.image
        if sketchnote != nil {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let dateAsString = formatter.string(from: sketchnote!.creationDate)
        let date = formatter.date(from: dateAsString)
        formatter.dateFormat = "dd MMM yyyy"
        let formattedDateAsString = formatter.string(from: date!)
        self.creationDateLabel.text = formattedDateAsString
        }
    }
    
    public func setDeleteAction(action: (() -> Void)?) {
        longPressAction = action
        isUserInteractionEnabled = true
        let selector = #selector(handleLongPress)
        let recognizer = UILongPressGestureRecognizer(target: self, action: selector)
        addGestureRecognizer(recognizer)
    }
}

fileprivate extension UIView {
    
    typealias Action = (() -> Void)
    
    struct Key { static var id = "longPressAction" }
    
    var longPressAction: Action? {
        get {
            return objc_getAssociatedObject(self, &Key.id) as? Action
        }
        set {
            guard let value = newValue else { return }
            let policy = objc_AssociationPolicy.OBJC_ASSOCIATION_RETAIN
            objc_setAssociatedObject(self, &Key.id, value, policy)
        }
    }
    
    @objc func handleLongPress(sender: UILongPressGestureRecognizer) {
        guard sender.state == .began else { return }
        longPressAction?()
    }
}

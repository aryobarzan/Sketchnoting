//
//  NoteTypedTextView.swift
//  Sketchnoting
//
//  Created by Aryobarzan on 27/08/2020.
//  Copyright © 2020 Aryobarzan. All rights reserved.
//

import UIKit

class NoteTypedTextView: NeoDraggableView {
    var label: FittableFontLabel
    
    override init(frame: CGRect) {
        label = FittableFontLabel(frame: frame)
        super.init(frame: frame)
        self.addSubview(label)
        label.isUserInteractionEnabled = false
        label.translatesAutoresizingMaskIntoConstraints = false
        let margins = super.layoutMarginsGuide
        label.leadingAnchor.constraint(equalTo: margins.leadingAnchor, constant: 0).isActive = true
        label.trailingAnchor.constraint(equalTo: margins.trailingAnchor, constant: 0).isActive = true
        label.bottomAnchor.constraint(equalTo: margins.bottomAnchor, constant: 0).isActive = true
        label.topAnchor.constraint(equalTo: margins.topAnchor, constant: 0).isActive = true
        
        self.label.layer.borderColor = UIColor.systemGray.cgColor
        self.label.layer.borderWidth = 0.5
        
        self.label.leftInset = 1
        self.label.topInset = 1
        self.label.rightInset = 1
        self.label.bottomInset = 1
        
        self.label.numberOfLines = 0
        self.label.textAlignment = .left
        self.label.lineBreakMode = .byWordWrapping
        self.label.backgroundColor = .systemBackground
    }
    required init?(coder aDecoder: NSCoder) {
        label = FittableFontLabel()
        super.init(coder: aDecoder)
    }
}

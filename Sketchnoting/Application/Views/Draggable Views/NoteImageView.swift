//
//  NoteImageView.swift
//  Sketchnoting
//
//  Created by Kael on 27/08/2020.
//  Copyright © 2020 Aryobarzan. All rights reserved.
//

import UIKit

class NoteImageView: NeoDraggableView {
    var imageView: UIImageView
    
    override init(frame: CGRect) {
        imageView = UIImageView(frame: frame)
        super.init(frame: frame)
        self.addSubview(imageView)
        imageView.isUserInteractionEnabled = true
        imageView.translatesAutoresizingMaskIntoConstraints = false
        let margins = super.layoutMarginsGuide
        imageView.leadingAnchor.constraint(equalTo: margins.leadingAnchor, constant: 0).isActive = true
        imageView.trailingAnchor.constraint(equalTo: margins.trailingAnchor, constant: 0).isActive = true
        imageView.bottomAnchor.constraint(equalTo: margins.bottomAnchor, constant: 0).isActive = true
        imageView.topAnchor.constraint(equalTo: margins.topAnchor, constant: 0).isActive = true
        
        self.layer.borderColor = UIColor.systemGray.cgColor
        self.layer.borderWidth = 1
    }
    required init?(coder aDecoder: NSCoder) {
        imageView = UIImageView()
        super.init(coder: aDecoder)
    }
}

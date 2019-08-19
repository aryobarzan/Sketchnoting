//
//  SizeSlider.swift
//  Sketchnoting
//
//  Created by Aryobarzan on 19/08/2019.
//  Copyright © 2019 Aryobarzan. All rights reserved.
//

import UIKit

class SizeSlider: UISlider {
    var thumbTextLabel: UILabel = UILabel()

    /*override func trackRect(forBounds bounds: CGRect) -> CGRect {
        let customBounds = CGRect(origin: bounds.origin, size: CGSize(width: bounds.size.width, height: 10.0))
        super.trackRect(forBounds: customBounds)
        return customBounds
    }*/
    private var thumbFrame: CGRect {
        return thumbRect(forBounds: bounds, trackRect: trackRect(forBounds: bounds), value: value)
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        thumbTextLabel.frame = thumbFrame
        thumbTextLabel.text = Int(value).description
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        addSubview(thumbTextLabel)
        thumbTextLabel.font = thumbTextLabel.font.withSize(10)
        thumbTextLabel.textAlignment = .center
        thumbTextLabel.layer.zPosition = layer.zPosition + 1
    }
}

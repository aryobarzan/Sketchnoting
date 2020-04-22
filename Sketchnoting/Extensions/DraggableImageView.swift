//
//  DraggableView.swift
//  Pre-Edits
//
//  Created by Richard Stockdale on 03/06/2016.
//  Copyright © 2016 Junction Seven. All rights reserved.
//  Source: https://github.com/stropdale/Draggable-UIView/blob/master/Draggable%20Resizable%20UIView/ViewController.swift
//
import Foundation
import UIKit

import PopMenu

class DraggableImageView: UIImageView, DraggableViewDelegate {
    var delegate: DraggableImageViewDelegate?
    
    var draggableView: DraggableView!
    
    override func awakeFromNib() {
        self.draggableView.setUpGestureRecognisers()
        self.isUserInteractionEnabled = true
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        self.draggableView = DraggableView(view: self)
        self.draggableView.delegate = self
        self.isUserInteractionEnabled = true
        
        self.layer.borderColor = UIColor.systemGray.cgColor
        self.layer.borderWidth = 1
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    func setHighlight(isHighlighted: Bool) {
        if isHighlighted {
            self.layer.borderColor = UIColor.systemBlue.cgColor
            self.layer.borderWidth = 4
        }
        else {
            self.layer.borderColor = UIColor.systemGray.cgColor
            self.layer.borderWidth = 1
        }
    }
    
    //
    func draggableViewSizeChanged() {
        delegate?.draggableImageViewSizeChanged(source: self, scale: self.frame.size)
    }
    
    func draggableViewLocationChanged(location: CGPoint) {
        delegate?.draggableImageViewLocationChanged(source: self, location: location)
    }
    
    func draggableViewLongPressed() {
        delegate?.draggableImageViewDelete(source: self)
    }
}

protocol DraggableImageViewDelegate {
    func draggableImageViewSizeChanged(source: DraggableImageView, scale: CGSize)
    func draggableImageViewLocationChanged(source: DraggableImageView, location: CGPoint)
    func draggableImageViewDelete(source: DraggableImageView)
}

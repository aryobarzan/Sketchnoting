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

class DraggableImageView: UIImageView {
    
    let panGesture = UIPanGestureRecognizer()
    let pinchGesture = UIPinchGestureRecognizer()
    let longPressGesture = UILongPressGestureRecognizer()
    
    var firstX: CGFloat? // For panning
    var firstY: CGFloat? // For panning
    var lastScale: CGFloat? // For pinching
    
    var delegate: DraggableImageViewDelegate?
    
    override func awakeFromNib() {
        setUpGestureRecognisers()
        self.isUserInteractionEnabled = true
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setUpGestureRecognisers()
        self.isUserInteractionEnabled = true
        
        self.layer.borderColor = UIColor.systemGray.cgColor
        self.layer.borderWidth = 1
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    private func setUpGestureRecognisers () {
        panGesture.addTarget(self, action: #selector(panGestureChanged))
        pinchGesture.addTarget(self, action: #selector(pinchGestureChanged))
        longPressGesture.addTarget(self, action: #selector(longPressGestureTriggered))
        longPressGesture.minimumPressDuration = 0.5
        longPressGesture.delaysTouchesBegan = true
        
        self.addGestureRecognizer(panGesture)
        self.addGestureRecognizer(pinchGesture)
        self.addGestureRecognizer(longPressGesture)
    }
    
    @objc func panGestureChanged () {
        
        // 1. Calculate and set the new location
        var locationInSuperView = panGesture.translation(in: self.superview) // Get the location of this view in the super view
        
        if panGesture.state == UIGestureRecognizer.State.began {
            firstX = self.center.x
            firstY = self.center.y

        }
        
        if firstX != nil && firstY != nil {
            locationInSuperView = CGPoint(x: firstX!+locationInSuperView.x, y: firstY!+locationInSuperView.y)
            // Don't let the image be dragged outside the superview
            if locationInSuperView.x > self.frame.size.width/2 && locationInSuperView.y > self.frame.size.height/2 && locationInSuperView.x/2 < self.superview!.frame.size.width && locationInSuperView.y/2 < self.superview!.frame.size.height {
                self.center = locationInSuperView
                delegate?.draggableImageViewLocationChanged(source: self, location: locationInSuperView)
            }
        }
    }
    
    @objc func pinchGestureChanged () {
        if pinchGesture.state == UIGestureRecognizer.State.began {
            lastScale = 1.0
        }
               
        if lastScale != nil {
            let scale = 1.0 - (lastScale! - pinchGesture.scale)
                   
            let newTransform: CGAffineTransform = self.transform.scaledBy(x: scale, y: scale)
                                      
            if shouldViewSizeChange(height: self.frame.size.height) {
                self.transform = newTransform
                lastScale = pinchGesture.scale
                delegate?.draggableImageViewSizeChanged(source: self, scale: self.frame.size)
            }
        }
    }
    
    @objc func longPressGestureTriggered() {
        if longPressGesture.state != .ended {
            delegate?.draggableImageViewDelete(source: self)
        }
    }
        
    func shouldViewSizeChange (height: CGFloat) -> Bool {
        let maxHeight: CGFloat = self.superview!.frame.size.height
        let minHeight: CGFloat = 140.0
        
        if height > minHeight && height < maxHeight {
            return true
        }
        else {
            if height > maxHeight && pinchGesture.scale < lastScale! {
                return true;
            }
            if height < minHeight && pinchGesture.scale > lastScale! {
                return true
            }
            
            return false
        }
    }
}

protocol DraggableImageViewDelegate {
    func draggableImageViewSizeChanged(source: DraggableImageView, scale: CGSize)
    func draggableImageViewLocationChanged(source: DraggableImageView, location: CGPoint)
    func draggableImageViewDelete(source: DraggableImageView)
}

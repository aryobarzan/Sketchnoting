//
//  NeoDraggableView.swift
//  Sketchnoting
//
//  Created by Aryobarzan on 27/08/2020.
//  Copyright © 2020 Aryobarzan. All rights reserved.
//

import UIKit

class NeoDraggableView: UIView {
    let panGesture = UIPanGestureRecognizer()
    let pinchGesture = UIPinchGestureRecognizer()
    let longPressGesture = UILongPressGestureRecognizer()
    
    var firstX: CGFloat? // For panning
    var firstY: CGFloat? // For panning
    var lastScale: CGFloat? // For pinching
    
    var delegate: NeoDraggableViewDelegate?
    
    override func awakeFromNib() {
        self.setUpGestureRecognisers()
        self.isUserInteractionEnabled = true
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        self.isUserInteractionEnabled = true
        setUpGestureRecognisers()
        
        self.layer.borderColor = UIColor.systemGray.cgColor
        self.layer.borderWidth = 1
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    func setUpGestureRecognisers () {
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
        var locationInSuperView = panGesture.translation(in: self.superview)
        if panGesture.state == UIGestureRecognizer.State.began {
            firstX = self.center.x
            firstY = self.center.y
        }
        if firstX != nil && firstY != nil {
            locationInSuperView = CGPoint(x: firstX!+locationInSuperView.x, y: firstY!+locationInSuperView.y)
            // Don't let the textView be dragged outside the superview
            if locationInSuperView.x > self.frame.size.width/2 && locationInSuperView.y > self.frame.size.height/2 && locationInSuperView.x/2 < self.superview!.frame.size.width && locationInSuperView.y/2 < self.superview!.frame.size.height {
                self.center = locationInSuperView
                delegate?.draggableViewLocationChanged(source: self, location: locationInSuperView)
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
                delegate?.draggableViewSizeChanged(source: self, scale: self.frame.size)
            }
        }
        if pinchGesture.state == .ended {
            //view.adjustFontSize()
        }
    }
    
    @objc func longPressGestureTriggered() {
        if longPressGesture.state != .ended {
            delegate?.draggableViewLongPressed(source: self)
        }
    }
        
    func shouldViewSizeChange (height: CGFloat) -> Bool {
        let maxHeight: CGFloat = self.superview!.frame.size.height
        let minHeight: CGFloat = 150.0
        
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
    
    // ----
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
}

protocol NeoDraggableViewDelegate {
    func draggableViewSizeChanged(source: NeoDraggableView, scale: CGSize)
    func draggableViewLocationChanged(source: NeoDraggableView, location: CGPoint)
    func draggableViewDelete(source: NeoDraggableView)
    func draggableViewLongPressed(source: NeoDraggableView)
}

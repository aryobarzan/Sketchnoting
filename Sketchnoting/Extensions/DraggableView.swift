//
//  DraggableView.swift
//  Sketchnoting
//
//  Created by Aryobarzan on 22/04/2020.
//  Copyright © 2020 Aryobarzan. All rights reserved.
//

import UIKit

class DraggableView {
    let panGesture = UIPanGestureRecognizer()
    let pinchGesture = UIPinchGestureRecognizer()
    let longPressGesture = UILongPressGestureRecognizer()
    
    var firstX: CGFloat? // For panning
    var firstY: CGFloat? // For panning
    var lastScale: CGFloat? // For pinching
    
    var delegate: DraggableViewDelegate?
    
    var view: UIView!
    init(view: UIView) {
        self.view = view
        setUpGestureRecognisers()
    }
    
    func setUpGestureRecognisers () {
        panGesture.addTarget(self, action: #selector(panGestureChanged))
        pinchGesture.addTarget(self, action: #selector(pinchGestureChanged))
        longPressGesture.addTarget(self, action: #selector(longPressGestureTriggered))
        longPressGesture.minimumPressDuration = 0.5
        longPressGesture.delaysTouchesBegan = true
        
        view.addGestureRecognizer(panGesture)
        view.addGestureRecognizer(pinchGesture)
        view.addGestureRecognizer(longPressGesture)
    }
    
    @objc func panGestureChanged () {
        // 1. Calculate and set the new location
        var locationInSuperView = panGesture.translation(in: view.superview) // Get the location of this view in the super view
        if panGesture.state == UIGestureRecognizer.State.began {
            firstX = view.center.x
            firstY = view.center.y
        }
        if firstX != nil && firstY != nil {
            locationInSuperView = CGPoint(x: firstX!+locationInSuperView.x, y: firstY!+locationInSuperView.y)
            // Don't let the textView be dragged outside the superview
            if locationInSuperView.x > view.frame.size.width/2 && locationInSuperView.y > view.frame.size.height/2 && locationInSuperView.x/2 < view.superview!.frame.size.width && locationInSuperView.y/2 < view.superview!.frame.size.height {
                view.center = locationInSuperView
                delegate?.draggableViewLocationChanged(location: locationInSuperView)
            }
        }
    }
    
    @objc func pinchGestureChanged () {
        if pinchGesture.state == UIGestureRecognizer.State.began {
            lastScale = 1.0
        }
               
        if lastScale != nil {
            let scale = 1.0 - (lastScale! - pinchGesture.scale)
            let newTransform: CGAffineTransform = view.transform.scaledBy(x: scale, y: scale)
                                      
            if shouldViewSizeChange(height: view.frame.size.height) {
                view.transform = newTransform
                lastScale = pinchGesture.scale
                delegate?.draggableViewSizeChanged()
            }
        }
        if pinchGesture.state == .ended {
            //view.adjustFontSize()
        }
    }
    
    @objc func longPressGestureTriggered() {
        if longPressGesture.state != .ended {
            delegate?.draggableViewLongPressed()
        }
    }
        
    func shouldViewSizeChange (height: CGFloat) -> Bool {
        let maxHeight: CGFloat = view.superview!.frame.size.height
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
}


protocol DraggableViewDelegate {
    func draggableViewSizeChanged()
    func draggableViewLocationChanged(location: CGPoint)
    func draggableViewLongPressed()
}

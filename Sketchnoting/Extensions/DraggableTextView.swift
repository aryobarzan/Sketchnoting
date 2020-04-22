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
import Highlightr

class DraggableTextView: FittableFontLabel, UITextViewDelegate, DraggableViewDelegate {
    var draggableDelegate: DraggableTextViewDelegate?
    
    var draggableView: DraggableView!
    
    override func awakeFromNib() {
        self.isUserInteractionEnabled = true
        self.draggableView.setUpGestureRecognisers()
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        self.draggableView = DraggableView(view: self)
        self.draggableView.delegate = self
        self.isUserInteractionEnabled = true
        
        self.layer.borderColor = UIColor.systemGray.cgColor
        self.layer.borderWidth = 0.5
        
        self.leftInset = 1
        self.topInset = 1
        self.rightInset = 1
        self.bottomInset = 1
        
        self.numberOfLines = 0
        self.textAlignment = .left
        self.lineBreakMode = .byWordWrapping
        self.backgroundColor = .systemBackground
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
    func textViewDidChange(_ textView: UITextView) {
        draggableDelegate?.draggableTextViewTextChanged(source: self, text: textView.text)
    }
    
    //
    func draggableViewSizeChanged() {
        self.draggableDelegate?.draggableTextViewSizeChanged(source: self, scale: self.frame.size)
        self.adjustFontSize()
    }
    
    func draggableViewLocationChanged(location: CGPoint) {
        self.draggableDelegate?.draggableTextViewLocationChanged(source: self, location: location)
    }
    
    func draggableViewLongPressed() {
        self.draggableDelegate?.draggableTextViewLongPressed(source: self)
    }
}

protocol DraggableTextViewDelegate {
    func draggableTextViewSizeChanged(source: DraggableTextView, scale: CGSize)
    func draggableTextViewLocationChanged(source: DraggableTextView, location: CGPoint)
    func draggableTextViewLongPressed(source: DraggableTextView)
    func draggableTextViewTextChanged(source: DraggableTextView, text: String)
}

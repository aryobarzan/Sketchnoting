//
//  UIViewControllerExtensions.swift
//  Sketchnoting
//
//  Created by Aryobarzan on 13/03/2019.
//  Copyright © 2019 Aryobarzan. All rights reserved.
//

import UIKit

extension UIViewController {
    func curveTopCorners() {
        let path = UIBezierPath(roundedRect: self.view.bounds,
                                byRoundingCorners: [.topLeft, .topRight],
                                cornerRadii: CGSize(width: 30, height: 0))
        let maskLayer = CAShapeLayer()
        maskLayer.frame = self.view.bounds
        maskLayer.path = path.cgPath
        self.view.layer.mask = maskLayer
    }
}

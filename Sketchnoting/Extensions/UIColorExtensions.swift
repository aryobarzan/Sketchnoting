//
//  UIColorExtensions.swift
//  Sketchnoting
//
//  Created by Aryobarzan on 07/12/2019.
//  Copyright © 2019 Aryobarzan. All rights reserved.
//

import UIKit

extension UIColor {
    
    var redValue: CGFloat{
        return cgColor.components! [0]
    }
    
    var greenValue: CGFloat{
        return cgColor.components! [1]
    }
    
    var blueValue: CGFloat{
        return cgColor.components! [2]
    }
    
    var alphaValue: CGFloat{
        return cgColor.components! [3]
    }
    
    var isWhiteText: Bool {
        
        // non-RGB color
        if cgColor.numberOfComponents == 2 {
            return 0.0...0.5 ~= cgColor.components!.first! ? true : false
        }
        
        let red = self.redValue * 255
        let green = self.greenValue * 255
        let blue = self.blueValue * 255
        
        // https://en.wikipedia.org/wiki/YIQ
        // https://24ways.org/2010/calculating-color-contrast/
        let yiq = ((red * 299) + (green * 587) + (blue * 114)) / 1000
        return yiq < 192
    }
    
    func image(_ size: CGSize = CGSize(width: 1, height: 1)) -> UIImage {
        return UIGraphicsImageRenderer(size: size).image { rendererContext in
            self.setFill()
            rendererContext.fill(CGRect(origin: .zero, size: size))
        }
    }
}


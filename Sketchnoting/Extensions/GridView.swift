//
//  GridView.swift
//  Sketchnoting
//
//  Created by Aryobarzan on 13/02/2020.
//  Copyright © 2020 Aryobarzan. All rights reserved.
//
import UIKit

class GridView: UIView {

    var type: HelpLinesType = .None
    var lineWidth: CGFloat = 0.5
    var lineColor: UIColor = UIColor.white

    override func draw(_ rect: CGRect) {
        if let context = UIGraphicsGetCurrentContext() {
            context.clear(rect)

            context.setLineWidth(lineWidth)
            context.setStrokeColor(lineColor.cgColor)
            
            if type == .Horizontal || type == .Grid {
                var height = CGFloat(30)
                while (CGFloat(height) < rect.height + 80) {
                        var startPoint = CGPoint.zero
                        var endPoint = CGPoint.zero
                        startPoint.x = 0.0
                        startPoint.y = CGFloat(height)
                        endPoint.x = frame.size.width
                        endPoint.y = startPoint.y
                        context.move(to: CGPoint(x: startPoint.x, y: startPoint.y))
                        context.addLine(to: CGPoint(x: endPoint.x, y: endPoint.y))
                        context.strokePath()
                     height = height + 30
                    }
            }
            if type == .Grid {
                var width = CGFloat(30)
                    while (CGFloat(width) < UIScreen.main.bounds.width + 80) {
                        var startPoint = CGPoint.zero
                        var endPoint = CGPoint.zero
                        startPoint.x = CGFloat(width)
                        startPoint.y = 0.0
                        endPoint.x = startPoint.x
                        endPoint.y = frame.size.height
                        context.move(to: CGPoint(x: startPoint.x, y: startPoint.y))
                        context.addLine(to: CGPoint(x: endPoint.x, y: endPoint.y))
                        context.strokePath()
                        width = width + 30
                }
            }
            
            
            /*numberOfColumns = Int(rect.width / 30) + 1
            let columnWidth = Int(rect.width) / (numberOfColumns + 1)
            for i in 1...numberOfColumns {
                var startPoint = CGPoint.zero
                var endPoint = CGPoint.zero
                startPoint.x = CGFloat(columnWidth * i)
                startPoint.y = 0.0
                endPoint.x = startPoint.x
                endPoint.y = frame.size.height
                context.move(to: CGPoint(x: startPoint.x, y: startPoint.y))
                context.addLine(to: CGPoint(x: endPoint.x, y: endPoint.y))
                context.strokePath()
            }

            let rowHeight = Int(rect.height) / (numberOfRows + 1)
            for j in 1...numberOfRows {
                var startPoint = CGPoint.zero
                var endPoint = CGPoint.zero
                startPoint.x = 0.0
                startPoint.y = CGFloat(rowHeight * j)
                endPoint.x = frame.size.width
                endPoint.y = startPoint.y
                context.move(to: CGPoint(x: startPoint.x, y: startPoint.y))
                context.addLine(to: CGPoint(x: endPoint.x, y: endPoint.y))
                context.strokePath()
            }*/
        }
    }
}

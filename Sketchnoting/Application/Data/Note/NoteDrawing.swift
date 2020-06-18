//
//  NoteDrawing.swift
//  Sketchnoting
//
//  Created by Aryobarzan on 18/06/2020.
//  Copyright © 2020 Aryobarzan. All rights reserved.
//

import UIKit

class NoteDrawing: Codable, Equatable {
    private var label: String
    private var region: CGRect
    private var recognitionDate: Date
    
    init(label: String, region: CGRect) {
        self.label = label
        self.region = region
        self.recognitionDate = Date()
    }
    
    public func getLabel() -> String {
        return label
    }
    public func getRegion() -> CGRect {
        return region
    }
    public func getRecognitionDate() -> Date {
        return recognitionDate
    }
    
    static func == (lhs: NoteDrawing, rhs: NoteDrawing) -> Bool {
        if lhs.region.intersects(rhs.region) && lhs.label == rhs.label {
            return true
        }
        return false
    }
}

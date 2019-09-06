//
//  SearchType.swift
//  Sketchnoting
//
//  Created by Aryobarzan on 05/09/2019.
//  Copyright © 2019 Aryobarzan. All rights reserved.
//

import UIKit

public enum SearchType: String {
    case All
    case Text
    case Drawing
    case Document
}

struct SearchFilter : Equatable {
    var term: String
    var type: SearchType
    
    static func == (lhs: SearchFilter, rhs: SearchFilter) -> Bool {
        if lhs.term == rhs.term && lhs.type == rhs.type {
            return true
        }
        return false
    }
}

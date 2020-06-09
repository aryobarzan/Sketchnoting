//
//  ArrayExtensions.swift
//  Sketchnoting
//
//  Created by Aryobarzan on 09/06/2020.
//  Copyright © 2020 Aryobarzan. All rights reserved.
//

import UIKit

extension Array where Element: Equatable {
    mutating func remove(object: Element) {
        guard let index = firstIndex(of: object) else {return}
        remove(at: index)
    }
}

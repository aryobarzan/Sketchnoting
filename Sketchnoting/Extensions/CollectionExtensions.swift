//
//  CollectionExtensions.swift
//  Sketchnoting
//
//  Created by Aryobarzan on 03/11/2020.
//  Copyright © 2020 Aryobarzan. All rights reserved.
//

import UIKit

extension Collection {
    func choose(_ n: Int) -> ArraySlice<Element> { shuffled().prefix(n) }
}

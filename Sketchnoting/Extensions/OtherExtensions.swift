//
//  OtherExtensions.swift
//  Sketchnoting
//
//  Created by Aryobarzan on 07/12/2019.
//  Copyright © 2019 Aryobarzan. All rights reserved.
//

import UIKit

class SketchnotingUtilities {
    public static func commonElements<T: Sequence, U: Sequence>(_ lhs: T, _ rhs: U) -> [T.Iterator.Element]
        where T.Iterator.Element: Equatable, T.Iterator.Element == U.Iterator.Element {
            var common: [T.Iterator.Element] = []

            for lhsItem in lhs {
                for rhsItem in rhs {
                    if lhsItem == rhsItem {
                        common.append(lhsItem)
                }
            }
        }
        return common
    }
}

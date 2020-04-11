//
//  URLExtensions.swift
//  Sketchnoting
//
//  Created by Aryobarzan on 12/04/2020.
//  Copyright © 2020 Aryobarzan. All rights reserved.
//

import UIKit

extension URL {
    var typeIdentifier: String? { (try? resourceValues(forKeys: [.typeIdentifierKey]))?.typeIdentifier }
    var localizedName: String? { (try? resourceValues(forKeys: [.localizedNameKey]))?.localizedName }
}

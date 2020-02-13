//
//  UserDefaultsExtensions.swift
//  Sketchnoting
//
//  Created by Aryobarzan on 03/09/2019.
//  Copyright © 2019 Aryobarzan. All rights reserved.
//

import UIKit

extension UserDefaults {
    static var settings: UserDefaults {
        return UserDefaults(suiteName: "lu.uni.coast.sketchnoting.settings")!
    }
    static var annotators: UserDefaults {
        return UserDefaults(suiteName: "lu.uni.coast.sketchnoting.annotators")!
    }
    static var hiddenDocuments: UserDefaults {
        return UserDefaults(suiteName: "lu.uni.coast.sketchnoting.hiddenDocuments")!
    }
    static var tags: UserDefaults {
        return UserDefaults(suiteName: "lu.uni.coast.sketchnoting.tags")!
    }
}

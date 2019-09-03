//
//  UserDefaultsExtensions.swift
//  Sketchnoting
//
//  Created by Aryobarzan on 03/09/2019.
//  Copyright © 2019 Aryobarzan. All rights reserved.
//

import UIKit

extension UserDefaults {
    static var sketchnotes: UserDefaults {
        return UserDefaults(suiteName: "lu.uni.coast.sketchnoting.sketchnotes")!
    }
    static var collections: UserDefaults {
        return UserDefaults(suiteName: "lu.uni.coast.sketchnoting.collections")!
    }
    static var settings: UserDefaults {
        return UserDefaults(suiteName: "lu.uni.coast.sketchnoting.settings")!
    }
    static var hiddenDocuments: UserDefaults {
        return UserDefaults(suiteName: "lu.uni.coast.sketchnoting.hiddenDocuments")!
    }
}

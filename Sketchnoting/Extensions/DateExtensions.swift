//
//  DateExtensions.swift
//  Sketchnoting
//
//  Created by Aryobarzan on 30/03/2020.
//  Copyright © 2020 Aryobarzan. All rights reserved.
//

import UIKit

extension Date {
    func getFormattedDate() -> String {
        let dateformat = DateFormatter()
        dateformat.dateFormat = "dd.MM.yyyy (HH:mm:ss)"
        return dateformat.string(from: self)
    }
}

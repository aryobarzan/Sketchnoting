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
    
    func fullDistance(from date: Date, resultIn component: Calendar.Component, calendar: Calendar = .current) -> Int? {
        calendar.dateComponents([component], from: self, to: date).value(for: component)
    }

    func distance(from date: Date, only component: Calendar.Component, calendar: Calendar = .current) -> Int {
        let days1 = calendar.component(component, from: self)
        let days2 = calendar.component(component, from: date)
        return days1 - days2
    }

    func hasSame(_ component: Calendar.Component, as date: Date) -> Bool {
        distance(from: date, only: component) == 0
    }
}

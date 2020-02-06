//
//  Notifications.swift
//  Sketchnoting
//
//  Created by Aryobarzan on 05/02/2020.
//  Copyright © 2020 Aryobarzan. All rights reserved.
//

import UIKit

class Notifications {
    static let NOTIFICATION_IMPORT_NOTE = "ImportSketchnote"
    static let NOTIFICATION_RECEIVE_NOTE = "ReceiveSketchnote"
    static let NOTIFICATION_DEVICE_VISIBILITY = "DeviceVisibility"

    
    static func announce(importedNoteURL: URL?) {
        if let url = importedNoteURL {
            var info = [String : URL]()
            info["importURL"] = url
            NotificationCenter.default.post(name: NSNotification.Name(rawValue: NOTIFICATION_IMPORT_NOTE), object: self, userInfo: info)
        }
    }
    static func announce(receivedNote: Sketchnote?) {
        if receivedNote != nil {
            NotificationCenter.default.post(name: NSNotification.Name(rawValue: NOTIFICATION_RECEIVE_NOTE), object: self)
        }
    }
    static func announceDeviceVisibility() {
        NotificationCenter.default.post(name: NSNotification.Name(rawValue: NOTIFICATION_DEVICE_VISIBILITY), object: self)
    }
}

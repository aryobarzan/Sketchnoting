//
//  DocumentsManager.swift
//  Sketchnoting
//
//  Created by Aryobarzan on 03/09/2019.
//  Copyright © 2019 Aryobarzan. All rights reserved.
//

import UIKit

class DocumentsManager {
    public static func hide(document: Document) {
        let encoder = JSONEncoder()
        
        if let encoded = try? encoder.encode(document) {
            UserDefaults.hiddenDocuments.set(encoded, forKey: document.title)
            log.info("Document \(document.title) hidden.")
        }
        else {
            log.error("Failed hiding document \(document.title).")
        }
    }
    public static func isHidden(document: Document) -> Bool {
        if let _ = UserDefaults.hiddenDocuments.data(forKey: document.title) {
            return true
        }
        return false
    }
}

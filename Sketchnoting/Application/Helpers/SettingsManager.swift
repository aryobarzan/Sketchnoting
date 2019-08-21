//
//  SettingsManager.swift
//  Sketchnoting
//
//  Created by Aryobarzan on 21/08/2019.
//  Copyright © 2019 Aryobarzan. All rights reserved.
//

import UIKit

class SettingsManager {
    public static func ignoreTouchInput() -> Bool {
        let ignoreTouchInput = UserDefaults.settings.bool(forKey: SettingsKeys.IgnoreTouchInput.rawValue)
        return ignoreTouchInput
    }
    public static func pencilSideButton() -> PencilSideButtonKeys {
        if let sideButton = UserDefaults.settings.string(forKey: SettingsKeys.PencilSideButton.rawValue) {
            switch sideButton {
            case PencilSideButtonKeys.ManageDrawings.rawValue:
                return PencilSideButtonKeys.ManageDrawings
            case PencilSideButtonKeys.ToggleEraserPencil.rawValue:
                return PencilSideButtonKeys.ToggleEraserPencil
            case PencilSideButtonKeys.ShowHideTools.rawValue:
                return PencilSideButtonKeys.ShowHideTools
            case PencilSideButtonKeys.Undo.rawValue:
                return PencilSideButtonKeys.Undo
            case PencilSideButtonKeys.Redo.rawValue:
                return PencilSideButtonKeys.Redo
            default:
                break
            }
        }
        return PencilSideButtonKeys.ManageDrawings
    }
    public static func noteSortingByNewest() -> Bool {
        return UserDefaults.settings.bool(forKey: SettingsKeys.NoteSortingByNewest.rawValue)
    }
}


public enum SettingsKeys : String, Any {
    case IgnoreTouchInput
    case PencilSideButton
    case NoteSortingByNewest
}
public enum PencilSideButtonKeys : String {
    case ManageDrawings
    case ToggleEraserPencil
    case ShowHideTools
    case Undo
    case Redo
}

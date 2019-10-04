//
//  SettingsManager.swift
//  Sketchnoting
//
//  Created by Aryobarzan on 21/08/2019.
//  Copyright © 2019 Aryobarzan. All rights reserved.
//

import UIKit

class SettingsManager {
    public static func firstAppStartup() -> Bool {
        let startup = UserDefaults.settings.bool(forKey: "FirstAppStartup")
        if !startup {
            UserDefaults.settings.set(true, forKey: "FirstAppStartup")
            return true
        }
        return false
    }
    public static func automaticAnnotation() -> Bool {
        return UserDefaults.settings.bool(forKey: SettingsKeys.AutomaticAnnotation.rawValue)
    }
    public static func pencilSideButton() -> PencilSideButtonKeys {
        if let sideButton = UserDefaults.settings.string(forKey: SettingsKeys.PencilSideButton.rawValue) {
            switch sideButton {
            case PencilSideButtonKeys.ManageDrawings.rawValue:
                return PencilSideButtonKeys.ManageDrawings
            case PencilSideButtonKeys.ToggleEraserPencil.rawValue:
                return PencilSideButtonKeys.ToggleEraserPencil
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
    public static func textRecognitionSetting() -> TextRecognitionSetting {
        if !UserDefaults.settings.bool(forKey: SettingsKeys.TextRecognitionCloud.rawValue) {
            return TextRecognitionSetting.OnDevice
        }
        else {
            if !UserDefaults.settings.bool(forKey: SettingsKeys.TextRecognitionCloudOption.rawValue) {
                return TextRecognitionSetting.CloudSparse
            }
            else {
                return TextRecognitionSetting.CloudDense
            }
        }
    }
}


public enum SettingsKeys : String, Any {
    case AutomaticAnnotation
    case PencilSideButton
    case NoteSortingByNewest
    case TextRecognitionCloud
    case TextRecognitionCloudOption
}
public enum PencilSideButtonKeys : String {
    case ManageDrawings
    case ToggleEraserPencil
    case Undo
    case Redo
}

public enum TextRecognitionSetting : String {
    case OnDevice
    case CloudSparse
    case CloudDense
}

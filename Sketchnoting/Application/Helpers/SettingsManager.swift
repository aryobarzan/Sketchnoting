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
    public static func setFileSorting(type: FileSorting) {
        UserDefaults.settings.set(type.rawValue, forKey: SettingsKeys.FileSorting.rawValue)
    }
    public static func getFileSorting() -> FileSorting {
        let typeString = UserDefaults.settings.value(forKey: SettingsKeys.FileSorting.rawValue) as? String ?? "ByNewest"
        let type = FileSorting(rawValue: typeString)
        return type ?? FileSorting.ByNewest
    }
    public static func setFileDisplayLayout(type: FileDisplayLayout) {
        UserDefaults.settings.set(type.rawValue, forKey: SettingsKeys.FileDisplayLayout.rawValue)
    }
    public static func getFileDisplayLayout() -> FileDisplayLayout {
        let typeString = UserDefaults.settings.value(forKey: SettingsKeys.FileDisplayLayout.rawValue) as? String ?? "Grid"
        let type = FileDisplayLayout(rawValue: typeString)
        return type ?? FileDisplayLayout.Grid
    }
    public static func setAnnotatorStatus(annotator: Annotator, status: Bool) {
        UserDefaults.annotators.set(status, forKey: annotator.rawValue)
    }
    public static func getAnnotatorStatus(annotator: Annotator) -> Bool {
        return UserDefaults.annotators.bool(forKey: annotator.rawValue)
    }
    public static func pencilSideButton() -> PencilSideButtonKeys {
        switch UserDefaults.settings.integer(forKey: SettingsKeys.PencilSideButtonDoubleTap.rawValue) {
            case 0:
                return PencilSideButtonKeys.ManageDrawings
            case 1:
                return PencilSideButtonKeys.System
            default:
                return PencilSideButtonKeys.ManageDrawings
        }
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
    
    public static func setNoteOptionsOrdering(orderingList: [NoteOption : Int]) {
        let p = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("NoteOptionsOrdering.json")
        do {
            try JSONEncoder().encode(orderingList).write(to: p)
            log.info("Saved Note Options ordering.")
        } catch {
            log.error("Failed to save Note Options ordering.")
        }
    }
    public static func getNoteOptionsOrdering() -> [NoteOption : Int]? {
        do {
            let p = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("NoteOptionsOrdering.json")
            let data = try Data(contentsOf: p)
            let ordering = try JSONDecoder().decode([NoteOption : Int].self, from: data)
            return ordering
        } catch {
            print(error)
            log.info("Failed to fetch Note Options ordering.")
            return nil
        }
    }
}


public enum SettingsKeys : String, Any {
    case AutomaticAnnotation
    case PencilSideButtonDoubleTap
    case TextRecognitionCloud
    case TextRecognitionCloudOption
    case FileSorting
    case FileDisplayLayout
    case NoteOptionsOrdering
}
public enum FileSorting: String {
    case ByNewest = "ByNewest"
    case ByOldest = "ByOldest"
    case ByNameAZ = "ByNameAZ"
    case ByNameZA = "ByNameZA"
}
public enum FileDisplayLayout: String {
    case Grid = "Grid"
    case List = "List"
}
public enum Annotator: String {
    case TAGME = "TAGME"
    case WAT = "WAT"
    case BioPortal = "BioPortal"
    case CHEBI = "CHEBI"
}
public enum PencilSideButtonKeys : String {
    case ManageDrawings
    case System
}

public enum TextRecognitionSetting : String {
    case OnDevice
    case CloudSparse
    case CloudDense
}

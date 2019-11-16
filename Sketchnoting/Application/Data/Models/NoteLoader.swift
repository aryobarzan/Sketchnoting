//
//  NoteLoader.swift
//  Sketchnoting
//
//  Created by Aryobarzan on 23/07/2019.
//  Copyright © 2019 Aryobarzan. All rights reserved.
//

import UIKit
import PencilKit

class NoteLoader {
    public static func loadSketchnotes() -> [Sketchnote]? {
        var sketchnotes = [Sketchnote]()
        do {
            let fileURLs = try FileManager.default.contentsOfDirectory(at: getSketchnotesDirectory(), includingPropertiesForKeys: nil)
            for url in fileURLs {
                do {
                    let data = try Data(contentsOf: url)
                    if let decodedNote = decodeNoteFromData(data: data) {
                        sketchnotes.append(decodedNote)
                    }
                } catch {
                    print("Failed to read note.")
                }
            }
        } catch {
            print("Error while enumerating files \(getSketchnotesDirectory().path): \(error.localizedDescription)")
        }
        
        if SettingsManager.noteSortingByNewest() {
            log.info("Sorting notes by newest first.")
            return sketchnotes.sorted(by: { (note0: Sketchnote, note1: Sketchnote) -> Bool in
                return note0 > note1
            })
        }
        else {
            return sketchnotes.sorted()
        }
    }
    
    public static func importSketchnoteFile(url: URL) -> Sketchnote? {
        do {
            let data = try Data(contentsOf: url)
            if let decodedNote = decodeNoteFromData(data: data) {
                return decodedNote
            }
        } catch {
            log.error("Failed to import sketchnote from file.")
        }
        return nil
    }
    
    public static func decodeNoteFromData(data: Data) -> Sketchnote? {
        if let decodedDataArray = try? NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(data) as? [Data] {
            if decodedDataArray.count >= 2 {
                let jsonDecoder = JSONDecoder()
                if let sketchnote = try? jsonDecoder.decode(Sketchnote.self, from: decodedDataArray[0]) {
                    if let pagesDecoded = ((try? NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(decodedDataArray[1]) as?
                            [NotePage]) as [NotePage]??) {
                            sketchnote.pages = pagesDecoded ?? [NotePage]()
                            return sketchnote
                        }
                }
            }
        }
        return nil
    }
    
    public static func getSketchnotesDirectory() -> URL {
        let documentsPath1 = NSURL(fileURLWithPath: NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0])
        let logsPath = documentsPath1.appendingPathComponent("sketchnotes")
        do
        {
            if !FileManager.default.fileExists(atPath: logsPath!.path) {
                try FileManager.default.createDirectory(atPath: logsPath!.path, withIntermediateDirectories: true, attributes: nil)
            }
            return logsPath!
        }
        catch let error as NSError
        {
            NSLog("Unable to create directory \(error.debugDescription)")
        }
        return logsPath!
    }
}

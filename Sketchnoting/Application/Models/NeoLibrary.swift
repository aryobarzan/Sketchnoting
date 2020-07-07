//
//  NeoLibrary.swift
//  Sketchnoting
//
//  Created by Aryobarzan on 06/07/2020.
//  Copyright © 2020 Aryobarzan. All rights reserved.
//

//import UIKit
//
//class NeoLibrary {
//    private static var navigationPath = [Folder]()
//    public static func getHomeDirectoryURL() -> URL {
//        let documentsPath = NSURL(fileURLWithPath: NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0])
//        let homeURL = documentsPath.appendingPathComponent("Home")
//        do
//        {
//            if !FileManager.default.fileExists(atPath: homeURL!.path) {
//                try FileManager.default.createDirectory(atPath: homeURL!.path, withIntermediateDirectories: true, attributes: nil)
//            }
//            return homeURL!
//        }
//        catch let error as NSError
//        {
//            log.error("Unable to create directory \(error.debugDescription)")
//        }
//        return homeURL!
//    }
//
//    public static func createFolder(name: String, root: URL = getHomeDirectoryURL()) -> Folder? {
//        let location = root.appendingPathComponent(name)
//        do
//        {
//            if !FileManager.default.fileExists(atPath: location.path) {
//                try FileManager.default.createDirectory(atPath: location.path, withIntermediateDirectories: true, attributes: nil)
//                return Folder(name: name, parent: nil, customID: nil, url: location)
//            }
//            log.error("Folder could not be created: A folder with the name \(name) already exists.")
//            return nil
//        }
//        catch _ as NSError
//        {
//            log.error("Unable to create folder.")
//        }
//        return nil
//    }
//
//    public static func move(file: File, toFolder folder: Folder) -> Bool {
//        if file.url != folder.url {
//            do
//            {
//                var name = file.getName()
//                while FileManager.default.fileExists(atPath: folder.url.appendingPathComponent(name).path) {
//                    name = name + " 2"
//                }
//                file.setName(name: name)
//                if file is Note {
//                    name = name + ".sketchnote"
//                }
//                try FileManager.default.moveItem(at: file.url, to: folder.url.appendingPathComponent(name))
//                file.url = folder.url.appendingPathComponent(name)
//                log.info("Moved file \(file.getName()) to \(folder.url.appendingPathComponent(name).path).")
//                return true
//            }
//            catch _ as NSError
//            {
//                log.error("Unable to move file \(file.getName()) to folder \(folder.getName()).")
//            }
//        }
//        return false
//    }
//}

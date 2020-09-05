//
//  ShareViewController.swift
//  Sketchnoting
//
//  Created by Aryobarzan on 04/09/2020.
//  Copyright © 2020 Aryobarzan. All rights reserved.
//

import UIKit

enum ExportAsType: String, CaseIterable {
    case PDF = "PDF"
    case Image = "Image"
    case Sketchnote = "Sketchnote"
}

struct ShareNoteSettings {
    var exportAsType: ExportAsType
    var selectedPages: [Int]
}

class ShareViewController: UIViewController, UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    
    @IBOutlet weak var shareItemsCollectionView: UICollectionView!
    @IBOutlet weak var shareButton: UIButton!
    @IBOutlet weak var quickActionsButton: UIButton!
    @IBOutlet weak var exportAsSingleFileSwitch: UISwitch!
    var files = [(URL, File)]()
    private var noteSettings = [URL : ShareNoteSettings]()

    override func viewDidLoad() {
        super.viewDidLoad()
        
        shareButton.layer.cornerRadius = 5
        shareButton.isEnabled = true
        
        // Not implemented
        quickActionsButton.isEnabled = false
        exportAsSingleFileSwitch.isEnabled = false

        shareItemsCollectionView.delegate = self
        shareItemsCollectionView.dataSource = self
        
        for file in files {
            if let note = file.1 as? Note {
                let settings = ShareNoteSettings(exportAsType: .PDF, selectedPages: Array(0..<note.pages.count))
                noteSettings[file.0] = settings
            }
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return files.count
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return CGSize(width: 220.0, height: 65.0)
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
         let cell = shareItemsCollectionView.dequeueReusableCell(withReuseIdentifier: "ShareItemViewCell", for: indexPath as IndexPath) as! ShareItemViewCell
        let file = files[indexPath.row]
        cell.layer.borderColor = UIColor.gray.cgColor
        cell.layer.borderWidth = 1
        cell.setItem(file: file.1, url: file.0)
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let file = files[indexPath.row]
        let cell = shareItemsCollectionView.cellForItem(at: indexPath) as! ShareItemViewCell
        let alert = UIAlertController(title: "File", message: "Remove this file from being exported, or change the format in which it should be exported.", preferredStyle: .actionSheet)
        alert.popoverPresentationController?.sourceView = cell
        
        if let note = file.1 as? Note {
            var settings = noteSettings[file.0]
            if settings == nil {
                settings = ShareNoteSettings(exportAsType: .PDF, selectedPages: Array(0..<note.pages.count))
            }
            for exportType in ExportAsType.allCases {
                let exportAction = UIAlertAction(title: "Export as \(exportType.rawValue)", style: .default) { action in
                    settings!.exportAsType = exportType
                    self.noteSettings[file.0] = settings!
                    cell.update(exportType: exportType)
                }
                alert.addAction(exportAction)
            }
        }
        
        let removeAction = UIAlertAction(title: "Remove", style: .destructive) { action in
            self.files.remove(at: indexPath.row)
            self.shareItemsCollectionView.reloadData()
            if self.files.count == 0 {
                self.shareButton.isEnabled = false
            }
        }
        alert.addAction(removeAction)
        
        self.present(alert, animated: true)
    }
    
    @IBAction func shareButtonTapped(_ sender: UIButton) {
        NeoLibrary.clearTemporaryExportFolder()
        if exportAsSingleFileSwitch.isOn {
            log.error("Not implemented.")
        }
        else {
            var activityItems = [Any]()
            var isGeneratingPDF = false
            var isGeneratingImage = false
            for file in files {
                if let note = file.1 as? Note {
                    switch noteSettings[file.0]!.exportAsType {
                    case .PDF:
                        isGeneratingPDF = true
                        note.createPDF2() { pdf in
                            if let pdf = pdf {
                                activityItems.append(pdf)
                                isGeneratingPDF = false
                            }
                        }
                    case .Image:
                        for page in note.pages {
                            isGeneratingImage = true
                            page.getAsImage() { image in
                            if let jpegData = image.jpegData(compressionQuality: 1) {
                                activityItems.append(jpegData)
                            }
                            isGeneratingImage = false
                            }
                        }
                    case .Sketchnote:
                        activityItems.append(file.0)
                        break
                    }
                }
                else { // Folder is exported
                    if FileManager.default.fileExists(atPath: file.0.path) {
                        let zippedURL = NeoLibrary.createZIPForExportOf(folder: file.0)
                        activityItems.append(zippedURL)
                    }
                }
            }
            // VERY BAD CODING FOLLOWS: (TO UPDATE)
            DispatchQueue.global(qos: .background).async {
                while isGeneratingPDF || isGeneratingImage {
                    // Waiting...
                }
                DispatchQueue.main.async {
                    let activityController = UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
                    self.present(activityController, animated: true, completion: nil)
                    if let popOver = activityController.popoverPresentationController {
                        popOver.sourceView = self.shareButton
                    }
                }
                
            }
            
        }
    }
    
    @IBAction func quickActionsButtonTapped(_ sender: UIButton) {
    }
    
    @IBAction func doneTapped(_ sender: UIBarButtonItem) {
        self.dismiss(animated: true, completion: nil)
    }
}

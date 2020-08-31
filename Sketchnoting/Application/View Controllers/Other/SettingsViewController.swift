//
//  SettingsViewController.swift
//  Sketchnoting
//
//  Created by Aryobarzan on 21/08/2019.
//  Copyright © 2019 Aryobarzan. All rights reserved.
//

import UIKit
import Toast

class SettingsViewController: UITableViewController {

    @IBOutlet var automaticAnnotationSwitch: UISwitch!
    @IBOutlet var pencilSideButtonSegmentedControl: UISegmentedControl!
    @IBOutlet var textRecognitionSegmentedControl: UISegmentedControl!
    @IBOutlet var tagmeSwitch: UISwitch!
    @IBOutlet var bioportalSwitch: UISwitch!
    @IBOutlet weak var watSwitch: UISwitch!
    @IBOutlet var chebiSwitch: UISwitch!
    @IBOutlet weak var exportBackupButton: UIButton!
    override func viewDidLoad() {
        super.viewDidLoad()
        self.navigationController?.setNavigationBarHidden(false, animated: false)
        
        automaticAnnotationSwitch.setOn(SettingsManager.automaticAnnotation(), animated: false)
        tagmeSwitch.setOn(SettingsManager.getAnnotatorStatus(annotator: .TAGME), animated: false)
        watSwitch.setOn(SettingsManager.getAnnotatorStatus(annotator: .WAT), animated: false)
        bioportalSwitch.setOn(SettingsManager.getAnnotatorStatus(annotator: .BioPortal), animated: false)
        chebiSwitch.setOn(SettingsManager.getAnnotatorStatus(annotator: .CHEBI), animated: false)
        pencilSideButtonSegmentedControl.selectedSegmentIndex = UserDefaults.settings.integer(forKey: SettingsKeys.PencilSideButtonDoubleTap.rawValue)
        switch SettingsManager.textRecognitionSetting() {
        case .OnDevice:
            textRecognitionSegmentedControl.selectedSegmentIndex = 0
        case .CloudSparse:
            textRecognitionSegmentedControl.selectedSegmentIndex = 1
        case .CloudDense:
            textRecognitionSegmentedControl.selectedSegmentIndex = 2
        }
        FirebaseUsage.shared.getAPIUsage(completion: {remaining in
            self.textRecognitionSegmentedControl.setTitle("Cloud (Dense) [\(remaining)]", forSegmentAt: 2)
        })
    }
    // MARK: - Navigation

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
    }
    @IBAction func closeTapped(_ sender: UIBarButtonItem) {
        dismiss(animated: true, completion: nil)
    }
    
    @IBAction func automaticAnnotationSwitchChanged(_ sender: UISwitch) {
        UserDefaults.settings.set(sender.isOn, forKey: SettingsKeys.AutomaticAnnotation.rawValue)
    }
    @IBAction func tagmeSwitchChanged(_ sender: UISwitch) {
        SettingsManager.setAnnotatorStatus(annotator: .TAGME, status: sender.isOn)
    }
    @IBAction func watSwitchChanged(_ sender: UISwitch) {
        SettingsManager.setAnnotatorStatus(annotator: .WAT, status: sender.isOn)
    }
    @IBAction func bioportalSwitchChanged(_ sender: UISwitch) {
        SettingsManager.setAnnotatorStatus(annotator: .BioPortal, status: sender.isOn)
    }
    @IBAction func chebiSwitchChanged(_ sender: UISwitch) {
        SettingsManager.setAnnotatorStatus(annotator: .CHEBI, status: sender.isOn)
    }
    @IBAction func pencilSideButtonSegmentedControlChanged(_ sender: UISegmentedControl) {
        UserDefaults.settings.set(sender.selectedSegmentIndex, forKey: SettingsKeys.PencilSideButtonDoubleTap.rawValue)
    }
    @IBAction func textRecognitionSegmentedControlChanged(_ sender: UISegmentedControl) {
        switch sender.selectedSegmentIndex {
        case 0:
            UserDefaults.settings.set(false, forKey: SettingsKeys.TextRecognitionCloud.rawValue)
            break
        case 1:
            UserDefaults.settings.set(true, forKey: SettingsKeys.TextRecognitionCloud.rawValue)
            UserDefaults.settings.set(false, forKey: SettingsKeys.TextRecognitionCloudOption.rawValue)
            break
        case 2:
            UserDefaults.settings.set(true, forKey: SettingsKeys.TextRecognitionCloud.rawValue)
            UserDefaults.settings.set(true, forKey: SettingsKeys.TextRecognitionCloudOption.rawValue)
            break
        default:
            UserDefaults.settings.set(false, forKey: SettingsKeys.TextRecognitionCloud.rawValue)
            break
        }
    }
    @IBAction func backupNotesTapped(_ sender: UIButton) {
        let alertView = UIAlertController(title: "Creating backup...", message: "", preferredStyle: .alert)
        var isCancelled = false
        alertView.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: {(alert: UIAlertAction!) in
            isCancelled = true
        }))
        self.present(alertView, animated: true)
        let activityIndicator = UIActivityIndicatorView(frame: CGRect(x: 120, y: 40.0, width: 25, height: 25))
        activityIndicator.startAnimating()
        alertView.view.addSubview(activityIndicator)
        NeoLibrary.createBackup() { url in
            DispatchQueue.main.async {
                if let backupFileURL = url {
                    if FileManager.default.fileExists(atPath: backupFileURL.path) {
                        if (!isCancelled) {
                            let activityController = UIActivityViewController(activityItems: [backupFileURL], applicationActivities: nil)
                            alertView.dismiss(animated: true, completion: {
                                self.present(activityController, animated: true)
                                if let popOver = activityController.popoverPresentationController {
                                    popOver.sourceView = sender
                                }
                                activityController.completionWithItemsHandler = {(activityType, completed, returnedItems, error) in
                                    if (completed) {
                                        NeoLibrary.delete(url: backupFileURL)
                                        log.info("Deleted temporary backup zip file.")
                                    }
                                }
                            })
                        }
                        else {
                            NeoLibrary.delete(url: backupFileURL)
                            log.info("Deleted temporary backup zip file.")
                        }
                    }
                }
                else {
                    alertView.dismiss(animated: true) {
                        log.error("Backup failed.")
                    }
                }
            }
        }
    }
}


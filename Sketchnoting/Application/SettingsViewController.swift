//
//  SettingsViewController.swift
//  Sketchnoting
//
//  Created by Kael on 21/08/2019.
//  Copyright © 2019 Aryobarzan. All rights reserved.
//

import UIKit

class SettingsViewController: UITableViewController {

    @IBOutlet weak var ignoreTouchSwitch: UISwitch!
    @IBOutlet weak var pencilSideButtonSegmentedControl: UISegmentedControl!
    @IBOutlet weak var textRecognitionSegmentedControl: UISegmentedControl!
    override func viewDidLoad() {
        super.viewDidLoad()
        self.navigationController?.setNavigationBarHidden(false, animated: false)
        
        ignoreTouchSwitch.setOn(SettingsManager.ignoreTouchInput(), animated: false)
        
        switch SettingsManager.textRecognitionSetting() {
        case .OnDevice:
            textRecognitionSegmentedControl.selectedSegmentIndex = 0
        case .CloudSparse:
            textRecognitionSegmentedControl.selectedSegmentIndex = 1
        case .CloudDense:
            textRecognitionSegmentedControl.selectedSegmentIndex = 2
        }
    }
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
    }
    @IBAction func ignoreTouchSwitchChanged(_ sender: UISwitch) {
        UserDefaults.settings.set(sender.isOn, forKey: SettingsKeys.IgnoreTouchInput.rawValue)
    }
    @IBAction func pencilSideButtonSegmentedControlChanged(_ sender: UISegmentedControl) {
        switch sender.selectedSegmentIndex {
        case 0:
            UserDefaults.settings.set(PencilSideButtonKeys.ManageDrawings, forKey: SettingsKeys.PencilSideButton.rawValue)
            break
        case 1:
            UserDefaults.settings.set(PencilSideButtonKeys.ToggleEraserPencil, forKey: SettingsKeys.PencilSideButton.rawValue)
            break
        case 2:
            UserDefaults.settings.set(PencilSideButtonKeys.ShowHideTools, forKey: SettingsKeys.PencilSideButton.rawValue)
            break
        case 3:
            UserDefaults.settings.set(PencilSideButtonKeys.Undo, forKey: SettingsKeys.PencilSideButton.rawValue)
            break
        case 4:
            UserDefaults.settings.set(PencilSideButtonKeys.Redo, forKey: SettingsKeys.PencilSideButton.rawValue)
            break
        default:
            UserDefaults.settings.set(PencilSideButtonKeys.ManageDrawings, forKey: SettingsKeys.PencilSideButton.rawValue)
            break
        }
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
}


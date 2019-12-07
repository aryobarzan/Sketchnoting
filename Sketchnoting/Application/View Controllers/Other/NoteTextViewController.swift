//
//  NoteTextViewController.swift
//  Sketchnoting
//
//  Created by Aryobarzan on 08/11/2019.
//  Copyright © 2019 Aryobarzan. All rights reserved.
//

import UIKit
import NotificationBannerSwift

class NoteTextViewController: UIViewController {

    
    @IBOutlet var textView: UITextView!
    var note: Sketchnote?
    override func viewDidLoad() {
        super.viewDidLoad()

        if let note = note {
            self.title = note.getTitle()
            textView.text = note.getText()
        }
    }
   
    @IBAction func copyTapped(_ sender: UIBarButtonItem) {
        if let note = note {
            UIPasteboard.general.string = note.getText()
            let banner = FloatingNotificationBanner(title: note.getTitle(), subtitle: "Copied text to clipboard.", style: .info)
            banner.show()
        }
    }
    
    @IBAction func closeTapped(_ sender: UIBarButtonItem) {
        dismiss(animated: true, completion: nil)
    }
}

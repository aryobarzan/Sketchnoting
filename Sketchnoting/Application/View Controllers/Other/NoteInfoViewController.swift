//
//  NoteInfoViewController.swift
//  Sketchnoting
//
//  Created by Aryobarzan on 30/03/2020.
//  Copyright © 2020 Aryobarzan. All rights reserved.
//

import UIKit

class NoteInfoViewController: UIViewController {

    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var createdLabel: UILabel!
    @IBOutlet weak var updatedLabel: UILabel!
    @IBOutlet weak var pagesLabel: UILabel!
    @IBOutlet weak var documentsLabel: UILabel!
    @IBOutlet weak var hiddenDocumentsLabel: UILabel!
    @IBOutlet weak var tagsTextView: UITextView!
    @IBOutlet weak var drawingsTextView: UITextView!
    override func viewDidLoad() {
        super.viewDidLoad()
        nameLabel.text = SKFileManager.activeNote!.getName()
        createdLabel.text = "Created: \(SKFileManager.activeNote!.creationDate.getFormattedDate())"
        updatedLabel.text = "Updated: \(SKFileManager.activeNote!.updateDate.getFormattedDate())"
        pagesLabel.text = "Pages: \(SKFileManager.activeNote!.pages.count)"
        documentsLabel.text = "Documents: \(SKFileManager.activeNote!.documents.count)"
        hiddenDocumentsLabel.text = "Hidden Documents: \(SKFileManager.activeNote!.hiddenDocuments.count)"
        let tagsArray = SKFileManager.activeNote!.tags.map { $0.title! }
        tagsTextView.text = "Tags: \(tagsArray.joined(separator:" - "))"
        drawingsTextView.text = "Drawings: \(SKFileManager.activeNote!.getCurrentPage().drawingLabels.joined(separator:" - "))"
    }
}

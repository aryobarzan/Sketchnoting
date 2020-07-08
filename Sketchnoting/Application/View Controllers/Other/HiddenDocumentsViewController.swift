//
//  HiddenDocumentsViewController.swift
//  Sketchnoting
//
//  Created by Aryobarzan on 26/02/2020.
//  Copyright © 2020 Aryobarzan. All rights reserved.
//

import UIKit

class HiddenDocumentsViewController: UITableViewController {
    
    var note: (URL, Note)!
    override func viewDidLoad() {
        super.viewDidLoad()
    }

    // MARK: - Table view data source
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return note.1.hiddenDocuments.count
    }

    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "HiddenDocumentTableCell", for: indexPath) as! HiddenDocumentTableCell
        let document = note.1.hiddenDocuments[indexPath.row]
        cell.document = document
        cell.titleLabel.text = document.title
        return cell
    }

    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            // Delete the row from the data source
            let document = note.1.hiddenDocuments[indexPath.row]
            note.1.unhide(document: document)
            log.info("Hidden document unhidden.")
            tableView.deleteRows(at: [indexPath], with: .fade)
        } else if editingStyle == .insert {
        }
    }
    @IBAction func doneTapped(_ sender: UIBarButtonItem) {
        self.dismiss(animated: true, completion: nil)
    }
}

class HiddenDocumentTableCell: UITableViewCell {
    var document: Document?
    @IBOutlet weak var titleLabel: UILabel!
}

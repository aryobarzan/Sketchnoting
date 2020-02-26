//
//  HiddenDocumentsViewController.swift
//  Sketchnoting
//
//  Created by Aryobarzan on 26/02/2020.
//  Copyright © 2020 Aryobarzan. All rights reserved.
//

import UIKit

class HiddenDocumentsViewController: UITableViewController {
    
    var dictionary: [String : Document]!

    override func viewDidLoad() {
        super.viewDidLoad()

        self.navigationItem.rightBarButtonItem = self.editButtonItem
        
        dictionary = [String : Document]()
        for (key, data) in UserDefaults.hiddenDocuments.dictionaryRepresentation() {
            if let data = data as? Data {
                let decoder = JSONDecoder()
                if let document = try? decoder.decode(Document.self, from: data) {
                    dictionary[key] = document
                } else {
                    log.error("Could not decode hidden document.")
                }
            }
        }
    }

    // MARK: - Table view data source
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return dictionary.keys.count
    }

    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "HiddenDocumentTableCell", for: indexPath) as! HiddenDocumentTableCell
        let documentKey = Array(dictionary.keys)[indexPath.row]
        let document = dictionary[documentKey]!
        cell.document = document
        cell.titleLabel.text = document.title
        return cell
    }

    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            // Delete the row from the data source
            let documentKey = Array(dictionary.keys)[indexPath.row]
            let document = dictionary[documentKey]!
            DocumentsManager.unhide(document: document)
            log.info("Hidden document unhidden.")
            dictionary.removeValue(forKey: documentKey)
            tableView.deleteRows(at: [indexPath], with: .fade)
        } else if editingStyle == .insert {
        }
    }
}

class HiddenDocumentTableCell: UITableViewCell {
    var document: Document?
    @IBOutlet weak var titleLabel: UILabel!
}

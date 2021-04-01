//
//  ImportViewController.swift
//  Sketchnoting
//
//  Created by Aryobarzan on 01/04/2021.
//  Copyright © 2021 Aryobarzan. All rights reserved.
//

import UIKit

class ImportViewController: UIViewController, UITableViewDataSource, UITableViewDelegate, MoveFileViewControllerDelegate {
    
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var importButton: UIButton!
    
    var items = [(URL, Note)]()
    var importCompletion: ((Bool) -> Void)?
    
    var didImport: Bool = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        importButton.layer.cornerRadius = 4
        tableView.dataSource = self
        tableView.delegate = self
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return items.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "ImportTableViewCell", for: indexPath) as! ImportTableViewCell
        let item = items[indexPath.row]
        cell.titleLabel.text = item.1.getName()
        cell.previewImageView.image = nil
        item.1.getPreviewImage() { image in
            cell.previewImageView.image = image
        }
        if let range = item.0.deletingLastPathComponent().absoluteString.range(of: "Documents/") {
            let path = item.0.deletingLastPathComponent().absoluteString[range.upperBound...]
            cell.folderLabel.text = "Folder: \(path)"
        }
        
        return cell
    }
    
    func tableView(_ tableView: UITableView,
                   contextMenuConfigurationForRowAt indexPath: IndexPath,
                   point: CGPoint) -> UIContextMenuConfiguration? {
        return UIContextMenuConfiguration(identifier: nil,
                                          previewProvider: nil,
                                          actionProvider: { suggestedActions in
                                            let item = self.items[indexPath.row]
                                            
                                            let selectFolderAction = UIAction(title: "Select folder...", image: UIImage(systemName: "folder")) { action in
                                                if let moveFileVC = self.storyboard?.instantiateViewController(withIdentifier: "MoveFileViewController") as? MoveFileViewController {
                                                    moveFileVC.modalPresentationStyle = .formSheet
                                                    moveFileVC.mode = .Select
                                                    moveFileVC.filesToMove = [item]
                                                    moveFileVC.delegate = self
                                                    let navigationController = UINavigationController(rootViewController: moveFileVC)
                                                    navigationController.modalPresentationStyle = .formSheet
                                                    self.present(navigationController, animated: true, completion: nil)
                                                }
                                            }
                                            let suggestFolderAction =
                                                UIAction(title: "Suggest folder...",
                                                         image: UIImage(systemName: "sparkles")) { action in
                                                    if !SKIndexer.shared.isIndexed(note: item.1) {
                                                        var cancelled = false
                                                        self.displayLoadingAlert(title: "Indexing", subtitle: "This note needs to be indexed before Sketchnoting can provide suggestions...") {
                                                            // Cancelled by user
                                                            cancelled = true
                                                        }
                                                        SKIndexer.shared.indexLibrary(item.1) { isFinished in
                                                            if !cancelled {
                                                                DispatchQueue.main.async {
                                                                    self.dismissLoadingAlert()
                                                                    self.view.makeToast("The note is now indexed, you may retry the action now.", duration: TimeInterval(3), position: .center, title: "Folder suggestion", completion: nil)
                                                                }
                                                            }
                                                        }
                                                    }
                                                    else {
                                                        let similarNotes = NoteSimilarity.shared.similarNotes(for: item.1, noteIterator: NeoLibrary.getNoteIterator(), maxResults: 1, similarityMethod: .SemanticMatrix)
                                                        if !similarNotes.isEmpty {
                                                            let similarNote = similarNotes.first!
                                                            if similarNote.1 > 0.8 {
                                                                logger.info(similarNote.0.0.absoluteString)
                                                                self.view.makeToast("Suggestion found.", duration: TimeInterval(2), position: .center, title: "Folder suggestion", completion: nil)
                                                                var updatedItem = item
                                                                updatedItem.0 = similarNote.0.0.deletingLastPathComponent().appendingPathComponent(item.0.lastPathComponent)
                                                                self.items[indexPath.row] = updatedItem
                                                                self.reload()
                                                            }
                                                            else {
                                                                self.view.makeToast("No suggestions available.", duration: TimeInterval(2), position: .center, title: "Folder suggestion", completion: nil)
                                                            }
                                                        }
                                                        else {
                                                            self.view.makeToast("No suggestions available.", duration: TimeInterval(2), position: .center, title: "Folder suggestion", completion: nil)
                                                        }
                                                    }
                                                }
                                            let removeAction =
                                                UIAction(title: "Remove",
                                                         image: UIImage(systemName: "trash.circle"), attributes: .destructive) { action in
                                                    self.items.remove(at: indexPath.row)
                                                    SKIndexer.shared.remove(note: item.1)
                                                    self.reload()
                                                }
                                            return UIMenu(title: "", children: [selectFolderAction, suggestFolderAction, removeAction])
                                          })
    }
    
    private func reload() {
        self.tableView.reloadData()
        if self.items.isEmpty {
            importButton.isEnabled = false
        }
    }
        
    @IBAction func importTapped(_ sender: UIButton) {
        self.didImport = true
        for (url, note) in items {
            NeoLibrary.saveSynchronously(note: note, url: url)
        }
        if let importCompletion = importCompletion {
            if self.items.isEmpty {
                importCompletion(false)
            }
            else {
                importCompletion(true)
            }
        }
        for (_, note) in self.items {
            if !SKIndexer.shared.isIndexed(note: note) {
                SKIndexer.shared.indexLibrary(note, finishHandler: nil)
            }
        }
        self.dismiss(animated: true, completion: nil)
    }
    
    @IBAction func cancelTapped(_ sender: Any) {
        cleanup()
        self.dismiss(animated: true, completion: nil)
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        cleanup()
        super.viewDidDisappear(animated)
    }
    
    private func cleanup() {
        if !didImport {
            for (_, note) in self.items {
                SKIndexer.shared.remove(note: note)
            }
        }
    }
    
    // MARK: MoveFileViewControllerDelegate
    
    func movedFiles(items: [(URL, File)]) {
    }
    
    func selectedFolder(url: URL, for notes: [(URL, File)]) {
        for note in notes {
            for (i, n) in self.items.enumerated() {
                if n.0 == note.0 {
                    self.items[i] = (url.appendingPathComponent(n.0.lastPathComponent), n.1)
                }
            }
        }
        self.reload()
    }
}

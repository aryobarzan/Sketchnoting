//
//  MoveFileViewController.swift
//  Sketchnoting
//
//  Created by Aryobarzan on 02/06/2020.
//  Copyright © 2020 Aryobarzan. All rights reserved.
//

import UIKit

class MoveFileViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {

    @IBOutlet weak var backButton: UIButton!
    @IBOutlet weak var tableView: UITableView!
    
    var delegate: MoveFileViewControllerDelegate?
    
    var filesToMove = [(URL, File)]()
    var currentFolder: URL = NeoLibrary.currentLocation
    var items = [URL]()
    override func viewDidLoad() {
        super.viewDidLoad()
        
        tableView.delegate = self
        tableView.dataSource = self
        
        self.updateItems()
    }
    
    func updateItems() {
        self.title = currentFolder.deletingPathExtension().lastPathComponent
        items = [URL]()
        for item in NeoLibrary.getFiles(atURL: currentFolder, foldersOnly: true) {
            items.append(item.0)
        }
        tableView.reloadData()
        if items.count == 0 {
            tableView.isHidden = true
        }
        else {
            tableView.isHidden = false
        }
        self.updateBackButton()
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return items.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "MoveFileViewCell", for: indexPath) as! MoveFileViewCell
        let folder = items[indexPath.row]
        cell.set(folderURL: folder)
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let selected = self.items[indexPath.item]
        self.currentFolder = selected
        self.updateItems()
    }

    private func updateBackButton() {
        if NeoLibrary.isHomeDirectory(url: self.currentFolder) {
            backButton.isHidden = true
        }
        else {
            backButton.isHidden = false
        }
    }

    @IBAction func newFolderTapped(_ sender: UIButton) {
        self.showInputDialog(title: "New Folder", subtitle: nil, actionTitle: "Create", cancelTitle: "Cancel", inputPlaceholder: "Folder Name...", inputKeyboardType: .default, cancelHandler: nil)
        { (input: String?) in
            var name = "Untitled"
            if let input = input {
                if !input.isEmpty {
                    name = input
                }
            }
            _ = NeoLibrary.createFolder(name: name, root: self.currentFolder)
            self.updateItems()
        }
    }
    @IBAction func backButtonTapped(_ sender: UIButton) {
        if !NeoLibrary.isHomeDirectory(url: currentFolder) {
            currentFolder = currentFolder.deletingLastPathComponent()
        }
        self.updateItems()
        
    }
    @IBAction func cancelTapped(_ sender: UIBarButtonItem) {
        self.dismiss(animated: true, completion: nil)
    }
    @IBAction func moveTapped(_ sender: UIBarButtonItem) {
        var newFiles = [(URL, File)]()
        for file in filesToMove {
            if let url = NeoLibrary.move(file: file.1, from: file.0, to: currentFolder) {
                newFiles.append((url, file.1))
            }
        }
        self.delegate?.movedFiles(items: newFiles)
        self.dismiss(animated: true, completion: nil)
    }
}


protocol MoveFileViewControllerDelegate {
    func movedFiles(items: [(URL, File)])
}

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
    
    var filesToMove = [File]()
    var currentFolder: Folder?
    var items = [Folder]()
    override func viewDidLoad() {
        super.viewDidLoad()
        
        tableView.delegate = self
        tableView.dataSource = self
        
        currentFolder = nil//SKFileManager.getFolder(id: file.parent)
        self.updateItems()
    }
    
    func updateItems() {
        self.title = currentFolder != nil ? currentFolder!.getName() : "Home"
        items = [Folder]()
        for item in DataManager.getFolderFiles(folder: currentFolder, foldersOnly: true) {
            if let f = item as? Folder {
                items.append(f)
            }
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
        cell.setFolder(folder: folder)
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let selected = self.items[indexPath.item]
        self.currentFolder = selected
        self.updateItems()
    }

    private func updateBackButton() {
        if self.currentFolder == nil {
            backButton.isHidden = true
        }
        else {
            backButton.isHidden = false
        }
    }

    @IBAction func newFolderTapped(_ sender: UIButton) {
        self.showInputDialog(title: "New Folder:", subtitle: nil, actionTitle: "Create", cancelTitle: "Cancel", inputPlaceholder: "Folder Name...", inputKeyboardType: .default, cancelHandler: nil)
        { (input: String?) in
            var name = "Untitled"
            if let input = input {
                if !input.isEmpty {
                    name = input
                }
            }
            let newFolder = Folder(name: name, parent: self.currentFolder?.id)
            _ = DataManager.add(folder: newFolder)
            self.updateItems()
        }
    }
    @IBAction func backButtonTapped(_ sender: UIButton) {
        self.currentFolder = DataManager.getFolder(id: currentFolder?.parent)
        self.updateItems()
        
    }
    @IBAction func cancelTapped(_ sender: UIBarButtonItem) {
        self.dismiss(animated: true, completion: nil)
    }
    @IBAction func moveTapped(_ sender: UIBarButtonItem) {
        for file in filesToMove {
            if file != currentFolder {
                DataManager.move(file: file, toFolder: currentFolder)
                
            }
        }
        self.delegate?.movedFiles(files: filesToMove)
        self.dismiss(animated: true, completion: nil)
    }
}


protocol MoveFileViewControllerDelegate {
    func movedFiles(files: [File])
}

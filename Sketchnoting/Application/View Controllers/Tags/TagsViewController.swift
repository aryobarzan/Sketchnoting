//
//  TagsViewController.swift
//  Sketchnoting
//
//  Created by Aryobarzan on 07/12/2019.
//  Copyright © 2019 Aryobarzan. All rights reserved.
//

import UIKit

class TagsViewController: UIViewController, UITableViewDataSource, UITableViewDelegate, TagTableViewCellDelegate {
   
    @IBOutlet weak var tagsTableView: UITableView!
    
    var isEditingTags: Bool = false
    var isFiltering: Bool = false
    
    var note: NoteX?
    override func viewDidLoad() {
        super.viewDidLoad()
        
        tagsTableView.delegate = self
        tagsTableView.dataSource = self
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        tagsTableView.reloadData()
        
        refreshSelectionAllowance()
    }
    
    private func refreshSelectionAllowance() {
        if isEditingTags {
            tagsTableView.allowsSelection = false
            tagsTableView.allowsMultipleSelection = false
        }
        else {
            tagsTableView.allowsSelection = true
            tagsTableView.allowsMultipleSelection = true
        }
    }
    

    @IBAction func editTapped(_ sender: UIBarButtonItem) {
        isEditingTags = !isEditingTags
        if isEditingTags {
            sender.title = "Done"
        }
        else {
            sender.title = "Edit"
        }
        tagsTableView.reloadData()
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return TagsManager.tags.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tagsTableView.dequeueReusableCell(withIdentifier: "TagTableViewCell", for: indexPath) as! TagTableViewCell
        
        let tag = TagsManager.tags[indexPath.row]
        cell.setTag(tag: tag)
        cell.delegate = self
        
        cell.deleteButton.isHidden = true
        if isEditingTags {
            cell.deleteButton.isHidden = false
        }
        
        return cell
    }
    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        if let cell = cell as? TagTableViewCell {
            if note != nil {
                for t in note!.tags {
                    if cell.noteTag == t {
                        tableView.selectRow(at: indexPath, animated: false, scrollPosition: .none)
                        break
                    }
                }
            }
            else if isFiltering {
                for t in TagsManager.filterTags {
                    if cell.noteTag == t {
                        tableView.selectRow(at: indexPath, animated: false, scrollPosition: .none)
                        break
                    }
                }
            }
        }
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
       self.updateTagSelections()
    }
    func tableView(_ tableView: UITableView, didDeselectRowAt indexPath: IndexPath) {
        self.updateTagSelections()
    }
    private func updateTagSelections() {
        var selectedTags = [Tag]()
            
        if let indexPathsForSelectedRows = tagsTableView.indexPathsForSelectedRows {
            for i in indexPathsForSelectedRows {
                if i.row < TagsManager.tags.count {
                    let tag = TagsManager.tags[i.row]
                    selectedTags.append(tag)
                }
            }
        }
        
        if note != nil {
            note!.tags = selectedTags
            SKFileManager.save(file: note!)
        }
        else if isFiltering {
            TagsManager.filterTags = selectedTags
        }
    }
    
    private func getSelectedTags() -> [Tag] {
        var selectedTags = [Tag]()
        if let indexPathsForSelectedRows = tagsTableView.indexPathsForSelectedRows {
            for i in indexPathsForSelectedRows {
                if i.row < TagsManager.tags.count {
                    let tag = TagsManager.tags[i.row]
                    selectedTags.append(tag)
                }
            }
        }
        return selectedTags
    }
    
    func deleteTagTapped(tag: Tag, sender: TagTableViewCell) {
        TagsManager.delete(tag: tag)
        tagsTableView.reloadData()
        self.updateTagSelections()
    }
       
}

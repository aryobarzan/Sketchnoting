//
//  SearchViewController.swift
//  Sketchnoting
//
//  Created by Aryobarzan on 11/02/2020.
//  Copyright © 2020 Aryobarzan. All rights reserved.
//

import UIKit
import NVActivityIndicatorView
import NaturalLanguage
class SearchViewController: UIViewController, UITextFieldDelegate, DrawingSearchDelegate, SKIndexerDelegate, UITableViewDelegate, UITableViewDataSource, SearchNoteCellDelegate {
    
    @IBOutlet weak var activityIndicator: NVActivityIndicatorView!
    @IBOutlet weak var updateButton: UIButton!
    @IBOutlet weak var searchTextField: UITextField!
    @IBOutlet weak var searchButton: UIButton!
    @IBOutlet weak var drawingSearchButton: UIButton!
    @IBOutlet weak var expandedSearchLabel: UILabel!
    @IBOutlet weak var expandedSearchSwitch: UISwitch!
    @IBOutlet weak var searchTableView: UITableView!
    
    var searchFilters = [SearchFilter]()
    var currentSearchType = SearchType.All

    fileprivate var items = [SearchTableItem]()
    
    var noteToOpen: (URL, Note)?
    
    private var appSearch = AppSearch()
    override func viewDidLoad() {
        super.viewDidLoad()
        self.tabBarController?.tabBar.isHidden = false
        
        searchTextField.delegate = self
        searchButton.layer.cornerRadius = 4
        
        searchTableView.dataSource = self
        searchTableView.delegate = self
    }
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }
    
    @IBAction func searchTapped(_ sender: UIButton) {
        performSearch()
        searchTextField.resignFirstResponder()
    }
  
    @IBAction func drawingSearchTapped(_ sender: UIButton) {
        let drawingSearchVC = UIStoryboard(name: "Main", bundle: Bundle.main).instantiateViewController(withIdentifier: "DrawingSearchViewController") as? DrawingSearchViewController
        if let drawingSearchVC = drawingSearchVC {
            drawingSearchVC.modalPresentationStyle = .popover
            drawingSearchVC.popoverPresentationController?.sourceView = sender
            present(drawingSearchVC, animated: true, completion: nil)
            drawingSearchVC.delegate = self
        }
    }
    func drawingSearchRecognized(label: String) {
        self.searchTextField.text = label
        performSearch()
    }
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        // Hide the keyboard.
        if textField.tag == 101 {
            searchTextField.resignFirstResponder()
            performSearch()
        }
        return true
    }
    @IBAction func expandedSearchSwitchChanged(_ sender: UISwitch) {
        if let text = searchTextField.text {
            if !text.isEmpty {
                performSearch()
            }
        }
    }
    @IBAction func updateButtonTapped(_ sender: UIButton) {
        sender.isEnabled = false
        activityIndicator.startAnimating()
        
        SKIndexer.shared.delegate = self
        SKIndexer.shared.cancelIndexing()
        SKIndexer.shared.indexLibrary(finishHandler: { finished in
            DispatchQueue.main.async {
                self.updateButton.setTitle("Update", for: .disabled)
                self.activityIndicator.stopAnimating()
                self.updateButton.isEnabled = true
            }
        })
    }
    
    func textFieldShouldClear(_ textField: UITextField) -> Bool {
        clear()
        return true
    }
    
    private func performSearch() {
        if let searchTextFieldText = searchTextField.text {
            if !searchTextFieldText.isEmpty {
                self.performSemanticSearch()
            }
        }
    }
    
    private func performSemanticSearch(specificQuery: String? = nil, useFullQuery: Bool = false) {
        let query = (specificQuery != nil) ? specificQuery! : searchTextField.text!.trimmingCharacters(in: .whitespacesAndNewlines)
        // Search
        clear()
        activityIndicator.isHidden = false
        activityIndicator.startAnimating()
        let searchResults = SemanticSearch.shared.search(query: query, expandedSearch: expandedSearchSwitch.isOn, useFullQuery: useFullQuery)
        if searchResults.count > 1 {
            let item = SearchTableInformationItem(query: query, message: "Your query '\(query)' has been split into \(Int(searchResults.count)) different subqueries: \(searchResults.map{"'\($0.query)'"}.joined(separator: ", ")). Do you want to view results for the full query?")
            self.items.append(item)
        }
        for result in searchResults {
            if !result.notes.isEmpty {
                let item = SearchTableNotesItem(query: result.query, notes: result.notes.map{($0.key, $0.value.0, $0.value.1)})
                self.items.append(item)
            }
            if !result.documents.isEmpty {
                let item = SearchTableDocumentsItem(query: result.query, documents: result.documents)
                self.items.append(item)
            }
            logger.info("Search Result for query '\(result.query)' - \(Int(result.notes.count)) notes / \(Int(result.documents.count)) Documents")
        }
        DispatchQueue.main.async {
            self.reload()
            self.activityIndicator.isHidden = true
        }
    }
    
    private func reload() {
        searchTableView.reloadData()
    }
    
    private func clear() {
        self.items.removeAll()
        self.reload()
    }

    @objc func switchToHomeTab() {
        tabBarController!.selectedIndex = 0
        if let nc = tabBarController!.viewControllers![0] as? UINavigationController {
            if let vc = nc.topViewController as? ViewController {
                vc.open(url: noteToOpen!.0, note: noteToOpen!.1)
            }
        }
    }
    
    // MARK: SKIndexerDelegate
    func skIndexerProgress(remainingOperations: Int) {
        DispatchQueue.main.async {
            self.updateButton.setTitle("Update (\(remainingOperations))", for: .disabled)
        }
    }
    
    // MARK: Table view
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return items.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let item = items[indexPath.row]
        switch item.type {
        case .Notes:
            let cell = searchTableView.dequeueReusableCell(withIdentifier: "SearchNoteCell", for: indexPath) as! SearchNoteCell
            if let notesItem = item as? SearchTableNotesItem {
                cell.setContent(query: item.query, notes: notesItem.notes)
            }
            cell.delegate = self
            return cell
        case .Documents:
            let cell = searchTableView.dequeueReusableCell(withIdentifier: "SearchDocumentCell", for: indexPath) as! SearchDocumentCell
            if let documentsItem = item as? SearchTableDocumentsItem {
                cell.setContent(query: item.query, documents: documentsItem.documents)
            }
            return cell
        case .Information:
            let cell = searchTableView.dequeueReusableCell(withIdentifier: "SearchInformationCell", for: indexPath) as! SearchInformationCell
            if let informationItem = item as? SearchTableInformationItem {
                cell.setContent(message: informationItem.message)
            }
            return cell
        }
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        let item = items[indexPath.row]
        switch item.type {
        case .Notes:
            return CGFloat(380)
        case .Documents:
            return CGFloat(210)
        case .Information:
            return CGFloat(60)
        }
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let item = items[indexPath.row]
        if item.type == .Information {
            self.items.remove(at: indexPath.row)
            self.searchTableView.deleteRows(at: [indexPath], with: .automatic)
            performSemanticSearch(specificQuery: item.query, useFullQuery: true)
        }
    }
    
    func tableView(_ tableView: UITableView, contextMenuConfigurationForRowAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
        return UIContextMenuConfiguration(identifier: nil, previewProvider: nil, actionProvider: { suggestedActions in
            let removeAction = UIAction(title: "Remove", image: UIImage(systemName: "trash.circle"), attributes: .destructive) { action in
                self.items.remove(at: indexPath.row)
                self.searchTableView.deleteRows(at: [indexPath], with: .automatic)
            }
            return UIMenu(title: "Search result", children: [removeAction])
        })
    }
    
    // MARK: SearchNoteCellDelegate
    func tappedNote(url: URL, note: Note) {
        noteToOpen = (url, note)
        Timer.scheduledTimer(timeInterval: 0.2, target: self, selector: #selector(switchToHomeTab), userInfo: nil, repeats: false)
    }
}

fileprivate class SearchTableItem {
    var type: SearchTableItemType
    var query: String
    init(query: String, type: SearchTableItemType = .Notes) {
        self.query = query
        self.type = type
    }
}

fileprivate class SearchTableNotesItem: SearchTableItem {
    var notes: [(URL, Note, Double)]
    init(query: String, notes: [(URL, Note, Double)]) {
        self.notes = notes
        super.init(query: query, type: .Notes)
    }
}

fileprivate class SearchTableDocumentsItem: SearchTableItem {
    var documents: [Document]
    init(query: String, documents: [Document]) {
        self.documents = documents
        super.init(query: query, type: .Documents)
    }
}

fileprivate class SearchTableInformationItem: SearchTableItem {
    var message: String
    init(query: String, message: String) {
        self.message = message
        super.init(query: query, type: .Information)
    }
}

fileprivate enum SearchTableItemType {
    case Notes
    case Documents
    case Information
}

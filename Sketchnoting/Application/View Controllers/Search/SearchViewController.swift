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
class SearchViewController: UIViewController, DrawingSearchDelegate, SKIndexerDelegate, UITableViewDelegate, UITableViewDataSource, SearchNoteCellDelegate, SearchDocumentCellDelegate, UISearchBarDelegate {
    
    @IBOutlet weak var searchBar: UISearchBar!
    @IBOutlet weak var activityIndicator: NVActivityIndicatorView!
    @IBOutlet weak var updateButton: UIButton!
    @IBOutlet weak var drawingSearchButton: UIButton!
    @IBOutlet weak var expandedSearchLabel: UILabel!
    @IBOutlet weak var expandedSearchSwitch: UISwitch!
    @IBOutlet weak var searchTableView: UITableView!

    fileprivate var items = [SearchTableItem]()
    var noteToOpen: (URL, Note)?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.tabBarController?.tabBar.isHidden = false
        searchBar.delegate = self
        searchTableView.dataSource = self
        searchTableView.delegate = self
        
        /*let wordEmbedding = SemanticSearch.shared.createWordEmbedding(type: .FastText)
        print((2 - wordEmbedding.distance(between: "skirmish", and: "battle"))/2)
        print((2 - wordEmbedding.distance(between: "king", and: "man"))/2)
        print((2 - wordEmbedding.distance(between: "king", and: "queen"))/2)
        print((2 - wordEmbedding.distance(between: "king", and: "woman"))/2)
        print((2 - wordEmbedding.distance(between: "science", and: "scientific"))/2)
        print((2 - wordEmbedding.distance(between: "apple", and: "orange"))/2)*/
    }
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }
    
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        performSearch()
        searchBar.resignFirstResponder()
    }
    
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        if searchText.isEmpty {
            DispatchQueue.main.async {
                self.clear()
            }
        }
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
        self.searchBar.text = label
        performSearch()
    }
    
    @IBAction func exploreButtonTapped(_ sender: UIButton) {
        if let exploreSearchVC = self.storyboard?.instantiateViewController(withIdentifier: "ExploreSearchViewController") as? ExploreSearchViewController {
            exploreSearchVC.modalPresentationStyle = .pageSheet
            present(exploreSearchVC, animated: true, completion: nil)
        }
    }
    
    @IBAction func expandedSearchSwitchChanged(_ sender: UISwitch) {
        if let text = searchBar.text {
            if !text.isEmpty {
                performSearch()
            }
        }
    }
    
    @IBAction func updateButtonTapped(_ sender: UIButton) {
        sender.isEnabled = false        
        SKIndexer.shared.delegate = self
        SKIndexer.shared.cancelIndexing()
        SKIndexer.shared.indexLibrary(finishHandler: { finished in
            DispatchQueue.main.async {
                self.updateButton.setTitle("Update", for: .disabled)
                self.updateButton.isEnabled = true
            }
        })
    }
    
    private func performSearch(specificQuery: String? = nil, useFullQuery: Bool = false) {
        let query = (specificQuery != nil) ? specificQuery! : searchBar.text?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let query = query {
            clear()
            activityIndicator.isHidden = false
            activityIndicator.startAnimating()
            let isExpandedSearch = expandedSearchSwitch.isOn
            DispatchQueue.global(qos: .userInitiated).async {
                SemanticSearch.shared.search(query: query, expandedSearch: isExpandedSearch, useFullQuery: useFullQuery, resultHandler: {result in
                    if !result.notes.isEmpty {
                        let item = SearchTableNotesItem(query: result.query, noteResults: result.notes)
                        self.items.append(item)
                    }
                    if !result.documents.isEmpty {
                        let item = SearchTableDocumentsItem(query: result.query, documents: result.documents)
                        self.items.append(item)
                    }
                    result.questionAnswers.forEach { answer in
                        let item = SearchTableInformationItem(query: query, message: "'\(query)' (\(answer.0)):\n \(answer.1) (\(Int(answer.2*100))% Confidence)", informationType: .QuestionAnswer)
                        self.items.append(item)
                    }
                    logger.info("Search Result for query '\(result.query)' - \(Int(result.notes.count)) notes / \(Int(result.documents.count)) Documents / \(Int(result.questionAnswers.count)) answers")
                    self.reload()
                    
                    
                }, subqueriesHandler: { queries in
                    if queries.count > 1 {
                        let item = SearchTableInformationItem(query: query, message: "Your query '\(query)' has been split into \(Int(queries.count)) different subqueries: \(queries.joined(separator: ", ")). Do you want to view results for the full query?", informationType: .Subqueries)
                        self.items.append(item)
                    }
                }, searchFinishHandler: {
                    DispatchQueue.main.async {
                        self.activityIndicator.isHidden = true
                        if self.items.isEmpty {
                            var message = "Sorry, no results could be found matching your query '\(query)'."
                            if !self.expandedSearchSwitch.isOn {
                                message += " Try enabling 'Expanded Search'!"
                            }
                            else {
                                let queryWords = SemanticSearch.shared.tokenize(text: query, unit: .word)
                                if queryWords.count > 3 {
                                    message += " Try shortening your query by only specifying 1 to 3 keywords!"
                                }
                                else if queryWords.count == 1 {
                                    message += " Double check the spelling of your query or try a different keyword!"
                                }
                            }
                            let item = SearchTableInformationItem(query: query, message: message, informationType: .Basic)
                            self.items.append(item)
                            self.reload()
                        }
                    }
                })
            }
        }
    }
    
    private func reload() {
        DispatchQueue.main.async {
            self.searchTableView.reloadData()
        }
    }
    
    private func clear() {
        self.items.removeAll()
        self.reload()
    }

    @objc func switchToHomeTab() {
        tabBarController!.selectedIndex = 0
        if let nc = tabBarController!.viewControllers![0] as? UINavigationController {
            if let vc = nc.topViewController as? ViewController {
                vc.open(url: noteToOpen!.0, file: noteToOpen!.1)
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
                cell.setContent(query: item.query, noteResults: notesItem.noteResults)
            }
            cell.delegate = self
            return cell
        case .Documents:
            let cell = searchTableView.dequeueReusableCell(withIdentifier: "SearchDocumentCell", for: indexPath) as! SearchDocumentCell
            if let documentsItem = item as? SearchTableDocumentsItem {
                cell.setContent(query: item.query, documents: documentsItem.documents)
            }
            cell.delegate = self
            return cell
        case .Information:
            let cell = searchTableView.dequeueReusableCell(withIdentifier: "SearchInformationCell", for: indexPath) as! SearchInformationCell
            if let informationItem = item as? SearchTableInformationItem {
                cell.setContent(message: informationItem.message, type: informationItem.informationType)
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
            return CGFloat(280)
        case .Information:
            return CGFloat(60)
        }
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let item = items[indexPath.row]
        if item.type == .Information {
            if let informationItem = item as? SearchTableInformationItem {
                switch informationItem.informationType {
                case .Basic, .QuestionAnswer:
                    self.presentDocumentDetail(document: Document(title: informationItem.query, description: informationItem.message, URL: "empty", documentType: .Other)!)
                    break
                case .Subqueries:
                    self.items.remove(at: indexPath.row)
                    self.searchTableView.deleteRows(at: [indexPath], with: .automatic)
                    performSearch(specificQuery: item.query, useFullQuery: true)
                    break
                }
            }
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
    
    func tappedExplainNoteResult(noteResult: SearchNoteResult) {
        self.presentSimpleTextView(title: "Why is note '\(noteResult.note.1.getName())' a result?", body: noteResult.resultExplanation)
    }
    
    // MARK: SearchDocumentCellDelegate
    func documentTapped(document: Document) {
        self.presentDocumentDetail(document: document)
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
    var noteResults: [SearchNoteResult]
    init(query: String, noteResults: [SearchNoteResult]) {
        self.noteResults = noteResults
        super.init(query: query, type: .Notes)
    }
}

fileprivate class SearchTableDocumentsItem: SearchTableItem {
    var documents: [(Document, Double)]
    init(query: String, documents: [(Document, Double)]) {
        self.documents = documents
        super.init(query: query, type: .Documents)
    }
}

fileprivate class SearchTableInformationItem: SearchTableItem {
    var message: String
    var informationType: SearchTableInformationItemType
    init(query: String, message: String, informationType: SearchTableInformationItemType = .Basic) {
        self.message = message
        self.informationType = informationType
        super.init(query: query, type: .Information)
    }
    
    
}

enum SearchTableInformationItemType {
    case Basic
    case QuestionAnswer
    case Subqueries
}

fileprivate enum SearchTableItemType {
    case Notes
    case Documents
    case Information
}

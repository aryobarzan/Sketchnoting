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
class SearchViewController: UIViewController, UITextFieldDelegate, DrawingSearchDelegate, SKIndexerDelegate, SearchNotesCardDelegate {
    
    @IBOutlet weak var activityIndicator: NVActivityIndicatorView!
    @IBOutlet weak var updateButton: UIButton!
    @IBOutlet weak var searchTextField: UITextField!
    @IBOutlet weak var searchButton: UIButton!
    @IBOutlet weak var drawingSearchButton: UIButton!
    @IBOutlet weak var expandedSearchLabel: UILabel!
    @IBOutlet weak var expandedSearchSwitch: UISwitch!
    @IBOutlet weak var contentStackView: UIStackView!
    @IBOutlet weak var dividerView: UIView!
    
    var searchFilters = [SearchFilter]()
    var currentSearchType = SearchType.All
    
    var searchNotesCards = [SearchNotesCard]()
    var searchDocumentsCards = [SearchDocumentsCard]()
    
    private var appSearch = AppSearch()
    override func viewDidLoad() {
        super.viewDidLoad()
        self.tabBarController?.tabBar.isHidden = false
        
        searchTextField.delegate = self
        searchButton.layer.cornerRadius = 4
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
            present(drawingSearchVC, animated: true, completion:nil)
            drawingSearchVC.delegate = self
        }
    }
    func drawingSearchRecognized(label: String) {
        // TODO
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
        clearSearchCards()
        return true
    }
    
    private func performSearch() {
        if let searchTextFieldText = searchTextField.text {
            if !searchTextFieldText.isEmpty {
                self.performSemanticSearch()
            }
        }
    }
    
    private func performSemanticSearch() {
        let query = searchTextField.text!.trimmingCharacters(in: .whitespacesAndNewlines)
        // Search
        clearSearchCards()
        activityIndicator.isHidden = false
        activityIndicator.startAnimating()
        let searchResults = SemanticSearch.shared.search(query: query, expandedSearch: expandedSearchSwitch.isOn)
        for result in searchResults {
            if !result.notes.isEmpty {
                createNotesCard(query: result.query, notes: result.notes.map{($0.key, $0.value.0, $0.value.1)})
            }
            if !result.documents.isEmpty {
                createDocumentsCard(documents: result.documents)
            }
            logger.info("Search Result for query '\(query)' - \(Int(result.notes.count)) notes / \(Int(result.documents.count)) Documents")
        }
        DispatchQueue.main.async {
            self.activityIndicator.isHidden = true
        }
    }
    
    private func createNotesCard(query: String, notes: [(URL, Note, Double)]) {
        DispatchQueue.main.async {
            let searchNotesCard = SearchNotesCard(query: query, notes: notes, frame: CGRect(x: 0, y: 0, width: 100, height: 400))
            searchNotesCard.delegate = self
            self.contentStackView.addArrangedSubview(searchNotesCard)
            self.searchNotesCards.append(searchNotesCard)
        }
    }
    
    private func createDocumentsCard(documents: [Document]) {
        DispatchQueue.main.async {
            let searchDocumentsCard = SearchDocumentsCard(documents: documents, frame: CGRect(x: 0, y: 0, width: 100, height: 400))
            self.contentStackView.addArrangedSubview(searchDocumentsCard)
            self.searchDocumentsCards.append(searchDocumentsCard)
        }
    }
    
    private func clearSearchCards() {
        for card in searchNotesCards {
            card.removeFromSuperview()
        }
        for card in searchDocumentsCards {
            card.removeFromSuperview()
        }
        searchNotesCards.removeAll()
        searchDocumentsCards.removeAll()
    }
    
    func noteTapped(url: URL, note: Note) {
        openNote(url: url, note: note)
    }
    
    var noteToOpen: (URL, Note)?
    func openNote(url: URL, note: Note) {
        noteToOpen = (url, note)
        Timer.scheduledTimer(timeInterval: 0.2, target: self, selector: #selector(switchToHomeTab), userInfo: nil, repeats: false)
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
}

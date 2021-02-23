//
//  SearchViewController.swift
//  Sketchnoting
//
//  Created by Aryobarzan on 11/02/2020.
//  Copyright © 2020 Aryobarzan. All rights reserved.
//

import UIKit

class SearchViewController: UIViewController, UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout, UITextFieldDelegate, DrawingSearchDelegate {
    
    @IBOutlet weak var searchModeSegmentedControl: UISegmentedControl!
    @IBOutlet weak var searchTextField: UITextField!
    @IBOutlet weak var searchButton: UIButton!
    @IBOutlet weak var drawingSearchButton: UIButton!
    @IBOutlet weak var searchTypeSegmentedControl: UISegmentedControl!
    @IBOutlet weak var filtersCollectionView: UICollectionView!
    @IBOutlet weak var notesCollectionView: UICollectionView!
    @IBOutlet weak var contentStackView: UIStackView!
    
    var searchFilters = [SearchFilter]()
    var notes = [(URL, Note)]()
    var currentSearchType = SearchType.All
    
    var searchDocumentsCards = [SearchDocumentsCard]()
    
    private var appSearch = AppSearch()
    override func viewDidLoad() {
        super.viewDidLoad()
        self.tabBarController?.tabBar.isHidden = false
        
        searchTextField.delegate = self
        
        searchButton.layer.cornerRadius = 14

        filtersCollectionView.delegate = self
        filtersCollectionView.dataSource = self
        notesCollectionView.delegate = self
        notesCollectionView.dataSource = self
    }
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        notesCollectionView.register(UINib(nibName: "NoteCollectionViewCell", bundle: nil), forCellWithReuseIdentifier: "NoteCollectionViewCell")
        filtersCollectionView.reloadData()
        notesCollectionView.reloadData()
    }
    
    @IBAction func searchModeSegmentChanged(_ sender: UISegmentedControl) {
        // Clear all search results first
        searchFilters.removeAll()
        filtersCollectionView.reloadData()
        self.updateResults()
        // Lexical Search
        if sender.selectedSegmentIndex == 0 {
            searchTypeSegmentedControl.isHidden = false
            filtersCollectionView.isHidden = false
        }
        // Semantic Search
        else {
            searchTypeSegmentedControl.isHidden = true
            filtersCollectionView.isHidden = true
            
        }
    }
    @IBAction func searchTapped(_ sender: UIButton) {
        performSearch()
        searchTextField.resignFirstResponder()
    }
    @IBAction func searchTypeSegmentChanged(_ sender: UISegmentedControl) {
        switch sender.selectedSegmentIndex {
            case 0: self.currentSearchType = .All
            case 1: self.currentSearchType = .Text
            case 2: self.currentSearchType = .Document
            case 3: self.currentSearchType = .Drawing
            default: self.currentSearchType = .All
        }
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
        createSearchFilter(term: label, type: .Drawing)
        self.updateResults()
    }
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        // Hide the keyboard.
        if textField.tag == 101 {
            searchTextField.resignFirstResponder()
            performSearch()
        }
        return true
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        if collectionView == filtersCollectionView {
            return searchFilters.count
        }
        else {
            return notes.count
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        if collectionView == filtersCollectionView {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "SearchFilterCollectionViewCell", for: indexPath as IndexPath) as! SearchFilterCollectionViewCell
            cell.setFilter(filter: searchFilters[indexPath.item])
            return cell
        }
        else {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "NoteCollectionViewCell", for: indexPath as IndexPath) as! NoteCollectionViewCell
            cell.setFile(url: notes[indexPath.item].0 ,file: notes[indexPath.item].1)
            return cell
        }
    }
    
    // MARK: UICollectionViewDelegate
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if collectionView == filtersCollectionView {
            searchFilters.remove(at: indexPath.item)
            filtersCollectionView.reloadData()
            self.updateResults()
        }
        else {
            self.openNote(url: self.notes[indexPath.item].0, note: self.notes[indexPath.item].1)
            log.info("Note tapped.")
        }
    }
    
    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        sizeForItemAt indexPath: IndexPath) -> CGSize {
        if collectionView == filtersCollectionView {
            return CGSize(width: CGFloat(117), height: CGFloat(21))
        }
        else {
            return CGSize(width: CGFloat(200), height: CGFloat(300))
        }
    }
    
    //
    private func performSearch() {
        if let searchTextFieldText = searchTextField.text {
            if !searchTextFieldText.isEmpty {
                if searchModeSegmentedControl.selectedSegmentIndex == 0 {
                    self.performLexicalSearch()
                }
                else {
                    self.performSemanticSearch()
                }
            }
        }
    }
    private func performLexicalSearch() {
        createSearchFilter(term: searchTextField.text!, type: self.currentSearchType)
        searchTextField.text = ""
        self.updateResults()
    }
    
    private func performSemanticSearch() {
        // Missing - This is currently only for testing
        let query = searchTextField.text!
        let tokens = SemanticSearch.shared.tokenize(text: query, unit: .word)
        for token in tokens {
            log.info(token)
        }
        let partsOfSpeechTags = SemanticSearch.shared.tag(text: query)
        for tag in partsOfSpeechTags {
            log.info("\(tag.0) - \(tag.1)")
        }
        let entities = SemanticSearch.shared.tag(text: query, scheme: .nameType)
        for entity in entities {
            log.info("\(entity.0) - \(entity.1)")
        }
        clearSearchDocumentsCards()
        self.notes = [(URL, Note)]()
        notesCollectionView.reloadData()
        SemanticSearch.shared.search(query: query, notes: NeoLibrary.getNotes(), searchHandler: {searchResult in
            if searchResult.note != nil {
                log.info("Match: Note - \(searchResult.note!.1.getName())")
                DispatchQueue.main.async {
                    self.notes.append(searchResult.note!)
                    self.notesCollectionView.reloadData()
                }
            }
            log.info("Document matches: \(searchResult.documents.count)")
            log.info("Location document matches: \(searchResult.locationDocuments.count)")
            log.info("Person document matches: \(searchResult.personDocuments.count)")
            if searchResult.documents.count > 0 {
                DispatchQueue.main.async {
                    let searchDocumentsCard = SearchDocumentsCard(documents: searchResult.documents, frame: CGRect(x: 0, y: 0, width: 100, height: 236))
                    self.contentStackView.addArrangedSubview(searchDocumentsCard)
                    self.searchDocumentsCards.append(searchDocumentsCard)
                }
            }
        })
    }
    
    private func clearSearchDocumentsCards() {
        for card in searchDocumentsCards {
            card.removeFromSuperview()
        }
        searchDocumentsCards = [SearchDocumentsCard]()
    }
    
    private func createSearchFilter(term: String, type: SearchType) {
        let termTrimmed = term.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let filter = SearchFilter(term: termTrimmed, type: type)
        if !searchFilters.contains(filter) {
            searchFilters.append(filter)
            filtersCollectionView.reloadData()
        }
    }
    
    private func updateResults() {
        self.notes = appSearch.search(filters: self.searchFilters)
        notesCollectionView.reloadData()
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
    
}

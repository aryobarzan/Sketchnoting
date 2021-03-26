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
class SearchViewController: UIViewController, UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout, UITextFieldDelegate, DrawingSearchDelegate, SKIndexerDelegate {
    
    @IBOutlet weak var activityIndicator: NVActivityIndicatorView!
    @IBOutlet weak var updateButton: UIButton!
    @IBOutlet weak var searchTextField: UITextField!
    @IBOutlet weak var searchButton: UIButton!
    @IBOutlet weak var drawingSearchButton: UIButton!
    @IBOutlet weak var expandedSearchLabel: UILabel!
    @IBOutlet weak var expandedSearchSwitch: UISwitch!
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
        
        searchButton.layer.cornerRadius = 4

        notesCollectionView.delegate = self
        notesCollectionView.dataSource = self
    }
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        notesCollectionView.register(UINib(nibName: "NoteCollectionViewCell", bundle: nil), forCellWithReuseIdentifier: "NoteCollectionViewCell")
        notesCollectionView.reloadData()
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
    @IBAction func expandedSearchSwitchChanged(_ sender: UISwitch) {
        if let text = searchTextField.text {
            if !text.isEmpty {
                performSearch()
            }
        }
    }
    @IBAction func updateButtonTapped(_ sender: UIButton) {
        logger.info("Updating...")
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
        clearResults()
        return true
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return notes.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "NoteCollectionViewCell", for: indexPath as IndexPath) as! NoteCollectionViewCell
        cell.setFile(url: notes[indexPath.item].0 ,file: notes[indexPath.item].1)
        return cell
    }
    
    // MARK: UICollectionViewDelegate
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        self.openNote(url: self.notes[indexPath.item].0, note: self.notes[indexPath.item].1)
        logger.info("Note tapped.")
    }
    
    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        sizeForItemAt indexPath: IndexPath) -> CGSize {
        return CGSize(width: CGFloat(200), height: CGFloat(300))
    }
    
    //
    
    private func clearResults() {
        self.notes = [(URL, Note)]()
        notesCollectionView.reloadData()
        self.clearSearchDocumentsCards()
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
        clearResults()
        activityIndicator.isHidden = false
        activityIndicator.startAnimating()
        let searchResults = SemanticSearch.shared.search(query: query, expandedSearch: expandedSearchSwitch.isOn)
        for (_, results) in searchResults {
            for searchResult in results {
                logger.info("Search Result - \(searchResult.note == nil ? "Note not a match" : searchResult.note!.1.getName()) / \(searchResult.documents.count) Documents / \(searchResult.personDocuments.count) Person-Documents / \(searchResult.locationDocuments.count) Location-Documents")
                if searchResult.note != nil {
                    DispatchQueue.main.async {
                        self.notes.append(searchResult.note!)
                        self.notesCollectionView.reloadData()
                    }
                }
                if searchResult.documents.count > 0 {
                    DispatchQueue.main.async {
                        let searchDocumentsCard = SearchDocumentsCard(documents: searchResult.documents, frame: CGRect(x: 0, y: 0, width: 100, height: 340))
                        self.contentStackView.addArrangedSubview(searchDocumentsCard)
                        self.searchDocumentsCards.append(searchDocumentsCard)
                    }
                }
            }
        }
        DispatchQueue.main.async {
            self.activityIndicator.isHidden = true
        }
    }
    
    private func clearSearchDocumentsCards() {
        for card in searchDocumentsCards {
            card.removeFromSuperview()
        }
        searchDocumentsCards = [SearchDocumentsCard]()
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
    
    // MARK: SKIndexerDelegate
    func skIndexerProgress(remainingOperations: Int) {
        logger.info(remainingOperations)
        DispatchQueue.main.async {
            self.updateButton.setTitle("Update (\(remainingOperations))", for: .disabled)
        }
    }
}

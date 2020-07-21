//
//  NeoDocumentsVC.swift
//  Sketchnoting
//
//  Created by Aryobarzan on 20/07/2020.
//  Copyright © 2020 Aryobarzan. All rights reserved.
//

import UIKit

import ViewAnimator
import PopMenu

protocol DocumentsViewControllerDelegate  {
    func resetDocuments()
    func updateTopicsCount()
}

class NeoDocumentsVC: UIViewController, UICollectionViewDelegate, UISearchBarDelegate {
    
    @IBOutlet weak var searchBar: UISearchBar!
    @IBOutlet weak var showHiddenSwitch: UISwitch!
    @IBOutlet var collectionView: UICollectionView!
    var searchActive = false
    
    var note: (URL, Note)!
    
    // MARK: - Properties
    private var sections = [Section]()
    private var dataSource: DataSource!
    private var searchController =  UISearchController(searchResultsController: nil)
    
    private var isSetup = false
    
    // MARK: - Value Types
    typealias DataSource = UICollectionViewDiffableDataSource<Section, Document>
    typealias Snapshot = NSDiffableDataSourceSnapshot<Section, Document>
    
    // MARK: Detail View
    var documentDetailVC: DocumentDetailViewController!
    
    // MARK: Delegate
    
    var delegate: DocumentsViewControllerDelegate?
    
    // MARK: - Life Cycles
    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.title = "Documents"
        collectionView.delegate = self
        configureLayout()
        self.dataSource = makeDataSource()
        searchBar.delegate = self
        if let textField = searchBar.value(forKey: "searchField") as? UITextField {
            textField.backgroundColor = .clear
            let backgroundView = textField.subviews.first
            if #available(iOS 11.0, *) { // If `searchController` is in `navigationItem`
                backgroundView?.backgroundColor = UIColor.clear //.withAlphaComponent(0.3)
                backgroundView?.subviews.forEach({ $0.removeFromSuperview() })
            }
        }
        
        let storyboard = UIStoryboard(name: "Main", bundle: Bundle.main)
        self.documentDetailVC = storyboard.instantiateViewController(withIdentifier: "DocumentDetailViewController") as? DocumentDetailViewController
        addChild(documentDetailVC)
        self.view.addSubview(documentDetailVC.view)
        documentDetailVC.view.frame = self.view.bounds
        documentDetailVC.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        documentDetailVC.didMove(toParent: self)
        documentDetailVC.view.isHidden = true
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        coordinator.animate(alongsideTransition: { context in
            self.collectionView.collectionViewLayout.invalidateLayout()
        }, completion: nil)
    }
    
    public func setup(note: (URL, Note)) {
        _ = self.view
        if (!isSetup) {
            self.note = note
            sections = getAllSections()
            applySnapshot(animatingDifferences: false)
            isSetup = true
        }
    }
    
    public func update(note: (URL, Note)?) {
        if note != nil {
            self.note = note
        }
        self.performSearch(searchText: searchBar.text ?? "")
    }
    
    public func clear() {
        self.searchBar.text = ""
    }
    
    private func resetDocuments() {
        self.note.1.clearDocuments()
        self.update(note: nil)
        self.delegate?.resetDocuments()
    }
    
    private func configureLayout() {
        collectionView.register(
            NeoDocumentsSectionHeader.self,
            forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader,
            withReuseIdentifier: NeoDocumentsSectionHeader.reuseIdentifier
        )
        collectionView.collectionViewLayout = UICollectionViewCompositionalLayout(sectionProvider: { (sectionIndex, layoutEnvironment) -> NSCollectionLayoutSection? in
            let size = NSCollectionLayoutSize(
                widthDimension: NSCollectionLayoutDimension.fractionalWidth(1),
                heightDimension: NSCollectionLayoutDimension.absolute(200)
            )
            let itemCount = Int(self.collectionView.frame.width / 210) //(self.collectionView.frame.size.width > 650) ? 3 : 2
            let item = NSCollectionLayoutItem(layoutSize: size)
            let group = NSCollectionLayoutGroup.horizontal(layoutSize: size, subitem: item, count: itemCount)
            let section = NSCollectionLayoutSection(group: group)
            section.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 10, bottom: 10, trailing: 10)
            section.interGroupSpacing = 10
            // Supplementary header view setup
            let headerFooterSize = NSCollectionLayoutSize(
                widthDimension: .fractionalWidth(1.0),
                heightDimension: .estimated(20)
            )
            let sectionHeader = NSCollectionLayoutBoundarySupplementaryItem(
                layoutSize: headerFooterSize,
                elementKind: UICollectionView.elementKindSectionHeader,
                alignment: .top
            )
            section.boundarySupplementaryItems = [sectionHeader]
            return section
        })
    }
    
    // MARK: - Functions
    private func makeDataSource() -> DataSource {
        let dataSource = DataSource(
            collectionView: collectionView,
            cellProvider: { (collectionView, indexPath, document) ->
                UICollectionViewCell? in
                // 2
                let cell = collectionView.dequeueReusableCell(
                    withReuseIdentifier: "NeoDocumentCell",
                    for: indexPath) as? NeoDocumentCell
                cell?.document = document
                return cell
        })
        dataSource.supplementaryViewProvider = { collectionView, kind, indexPath in
            guard kind == UICollectionView.elementKindSectionHeader else {
                return nil
            }
            let section = self.dataSource.snapshot()
                .sectionIdentifiers[indexPath.section]
            let view = collectionView.dequeueReusableSupplementaryView(
                ofKind: kind,
                withReuseIdentifier: NeoDocumentsSectionHeader.reuseIdentifier,
                for: indexPath) as? NeoDocumentsSectionHeader
            view?.titleLabel.text = section.documentType.rawValue
            return view
        }
        return dataSource
    }
    
    private func applySnapshot(animatingDifferences: Bool = true) {
        var snapshot = Snapshot()
        snapshot.appendSections(sections)
        sections.forEach { section in
            snapshot.appendItems(section.documents, toSection: section)
        }
        dataSource.apply(snapshot, animatingDifferences: animatingDifferences)
    }
    
    // MARK: Interactions
    func collectionView(
        _ collectionView: UICollectionView,
        didSelectItemAt indexPath: IndexPath
    ) {
        guard let document = dataSource.itemIdentifier(for: indexPath) else {
            return
        }
        documentDetailVC.setDocument(document: document)
        documentDetailVC.view.isHidden = false
        let animation = AnimationType.from(direction: .right, offset: 100.0)
        documentDetailVC.view.animate(animations: [animation])
    }
    
    func collectionView(_ collectionView: UICollectionView, contextMenuConfigurationForItemAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
        guard let document = dataSource.itemIdentifier(for: indexPath) else {
            return nil
        }
        return UIContextMenuConfiguration(identifier: nil, previewProvider: nil, actionProvider: { suggestedActions in
            return self.makeDocumentContextMenu(document: document)
        })
    }
    private func makeDocumentContextMenu(document: Document) -> UIMenu {
        var actions = [UIAction]()
        
        if let document = document as? TAGMEDocument {
            let subConceptsAction = UIAction(title: "Subconcepts", image: UIImage(systemName: "doc.text.magnifyingglass")) { action in
                TAGMEHelper.shared.checkForSubconcepts(document: document, note: self.note)
            }
            actions.append(subConceptsAction)
        }
        if document.isHidden {
            let unhideAction = UIAction(title: "Unhide", image: UIImage(systemName: "eye.slash")) { action in
                self.note.1.unhide(document: document)
                NeoLibrary.save(note: self.note.1, url: self.note.0)
                self.update(note: nil)
                self.delegate?.updateTopicsCount()
            }
            actions.append(unhideAction)
        }
        else {
            let hideAction = UIAction(title: "Hide", image: UIImage(systemName: "eye.slash")) { action in
                self.note.1.hide(document: document)
                NeoLibrary.save(note: self.note.1, url: self.note.0)
                self.update(note: nil)
                self.delegate?.updateTopicsCount()
            }
            actions.append(hideAction)
        }
        
        return UIMenu(title: document.title, children: actions)
    }
    
    //
    
    private func getAllSections() -> [Section] {
        var s = [Section]()
        for type in DocumentType.allCases {
            var docs = [Document]()
            for doc in note.1.getDocuments(includeHidden: showHiddenSwitch.isOn) {
                if (doc.documentType == type) {
                    docs.append(doc)
                }
            }
            docs.sort(by: {d1, d2 in
                return d1.title < d2.title
            })
            let section = Section(documentType: type, documents: docs)
            s.append(section)
        }
        s.sort(by: {s1, s2 in
            return s1.documents.count > s2.documents.count
        })
        return s
    }
    
    // MARK: Settings
    
    @IBAction func settingsTapped(_ sender: UIButton) {
        let popMenu = PopMenuViewController(sourceView: sender, actions: [PopMenuAction](), appearance: nil)
        popMenu.appearance.popMenuBackgroundStyle = .none()
        let tagmeEpsilonAction = PopMenuDefaultAction(title: "Change TAGME Accuracy", image: UIImage(systemName: "dial"),  didSelect: { action in
            popMenu.dismiss(animated: true, completion: nil)
            var title = "Favor Common Topics (More)"
            if self.note.1.tagmeEpsilon == Float(0.0) {
                title = "✔︎ Favor Common Topics (More)"
            }
            let alert = UIAlertController(title: "TAGME Accuracy", message: "Choose how documents are fetched.", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: NSLocalizedString(title, comment: ""), style: .default, handler: { _ in
                self.note.1.tagmeEpsilon = 0.0
                NeoLibrary.save(note: self.note.1, url: self.note.0)
            }))
            
            title = "Balanced"
            if self.note.1.tagmeEpsilon == Float(0.3) {
                title = "✔︎ Balanced"
            }
            alert.addAction(UIAlertAction(title: NSLocalizedString(title, comment: ""), style: .default, handler: { _ in
                self.note.1.tagmeEpsilon = 0.3
                NeoLibrary.save(note: self.note.1, url: self.note.0)
            }))
            
            title = "Favor Contextual Topics (Less)"
            if self.note.1.tagmeEpsilon == Float(0.5) {
                title = "✔︎ Favor Contextual Topics (Less)"
            }
            alert.addAction(UIAlertAction(title: NSLocalizedString(title, comment: ""), style: .default, handler: { _ in
                self.note.1.tagmeEpsilon = 0.5
                NeoLibrary.save(note: self.note.1, url: self.note.0)
            }))
            self.present(alert, animated: true, completion: nil)
        })
        popMenu.addAction(tagmeEpsilonAction)
        let resetAction = PopMenuDefaultAction(title: "Reset Documents", image: UIImage(systemName: "wand.and.rays"),  didSelect: { action in
            self.resetDocuments()
        })
        popMenu.addAction(resetAction)
        self.present(popMenu, animated: true, completion: nil)
    }
    
    @IBAction func showHiddenSwitchChanged(_ sender: UISwitch) {
        self.update(note: nil)
    }
    
    // MARK: Search bar
    func searchBarTextDidBeginEditing(_ searchBar: UISearchBar) {
        searchActive = true
    }
    
    func searchBarTextDidEndEditing(_ searchBar: UISearchBar) {
        searchActive = false
    }
    
    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        searchActive = false;
        
        searchBar.text = nil
        searchBar.resignFirstResponder()
        collectionView.resignFirstResponder()
        self.searchBar.showsCancelButton = false
        self.sections = getAllSections()
        applySnapshot()
    }
    
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchActive = false
    }
    
    func searchBarShouldEndEditing(_ searchBar: UISearchBar) -> Bool {
        return true
    }
    
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
       performSearch(searchText: searchText)
    }
    
    public func performSearch(searchText: String) {
        self.searchActive = true;
        self.searchBar.showsCancelButton = true
        if searchText.isEmpty {
            sections = getAllSections()
            applySnapshot()
        }
        else {
            self.searchBar.text = searchText
            let allSections = getAllSections()
            DispatchQueue.global(qos: .background).async {
                var results = [Section]()
                
                var queries = searchText.lowercased().components(separatedBy: ",")
                if queries.isEmpty {
                    queries.append(searchText.lowercased().trimmingCharacters(in: .whitespacesAndNewlines))
                }
                for sec in allSections {
                    var matches = [Document]()
                    for doc in sec.documents {
                        for query in queries {
                            if doc.title.lowercased().contains(query.trimmingCharacters(in: .whitespacesAndNewlines)) && !matches.contains(doc) {
                                matches.append(doc)
                                break
                            }
                        }
                        
                    }
                    if matches.count > 0 {
                        matches.sort(by: {d1, d2 in
                            return d1.title < d2.title
                        })
                        results.append(Section(documentType: sec.documentType, documents: matches))
                    }
                }
                results.sort(by: {s1, s2 in
                    return s1.documents.count > s2.documents.count
                })
                DispatchQueue.main.async {
                    self.sections = results
                    self.applySnapshot()
                }
            }
        }
    }
    
    public func hideDetailView() {
        self.documentDetailVC.view.isHidden = true
    }
}

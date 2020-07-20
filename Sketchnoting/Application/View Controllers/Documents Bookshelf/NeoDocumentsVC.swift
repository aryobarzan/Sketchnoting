//
//  NeoDocumentsVC.swift
//  Sketchnoting
//
//  Created by Aryobarzan on 20/07/2020.
//  Copyright © 2020 Aryobarzan. All rights reserved.
//

import UIKit

class NeoDocumentsVC: UIViewController, UICollectionViewDelegate, UISearchBarDelegate, UISearchResultsUpdating {
    
    @IBOutlet weak var searchBar: UISearchBar!
    @IBOutlet var collectionView: UICollectionView!
    var searchActive = false
    
    var note: (URL, Note)!
    
    // MARK: - Properties
    private var sections = [Section]()
    private var sectionsAll = [Section]()
    private var dataSource: DataSource!
    private var searchController =  UISearchController(searchResultsController: nil)
    
    private var isSetup = false
    
    // MARK: - Value Types
    typealias DataSource = UICollectionViewDiffableDataSource<Section, Document>
    typealias Snapshot = NSDiffableDataSourceSnapshot<Section, Document>
    
    // MARK: - Life Cycles
    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.title = "Documents"
        collectionView.delegate = self
        configureSearchController()
        configureLayout()
        self.dataSource = makeDataSource()
        searchBar.delegate = self
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
            for type in DocumentType.allCases {
                var docs = [Document]()
                for doc in note.1.getDocuments() {
                    if (doc.documentType == type) {
                        docs.append(doc)
                    }
                }
                let section = Section(documentType: type, documents: docs)
                sections.append(section)
                sectionsAll.append(section)
            }
            applySnapshot(animatingDifferences: false)
            isSetup = true
        }
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
            let itemCount = 2
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
    func makeDataSource() -> DataSource {
        // 1
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
    
    // 1
    func applySnapshot(animatingDifferences: Bool = true) {
        // 2
        var snapshot = Snapshot()
        // 3
        snapshot.appendSections(sections)
        // 4
        sections.forEach { section in
            snapshot.appendItems(section.documents, toSection: section)
        }
        // 5
        dataSource.apply(snapshot, animatingDifferences: animatingDifferences)
    }
    
    //
    func collectionView(
        _ collectionView: UICollectionView,
        didSelectItemAt indexPath: IndexPath
    ) {
        guard let document = dataSource.itemIdentifier(for: indexPath) else {
            log.error("Nope")
            return
        }
        log.info("Selected.")
    }
    
    func updateSearchResults(for searchController: UISearchController) {
        sections = filteredSections(for: searchController.searchBar.text)
        applySnapshot()
    }
    
    func filteredSections(for queryOrNil: String?) -> [Section] {
        let sectionsTemp = sections
        guard
            let query = queryOrNil,
            !query.isEmpty
            else {
                return sections
        }
        
        return sectionsTemp.filter { section in
            var matches = section.documentType.rawValue.lowercased().contains(query.lowercased())
            for doc in section.documents {
                if doc.title.lowercased().contains(query.lowercased()) {
                    matches = true
                    break
                }
            }
            return matches
        }
    }
    
    func configureSearchController() {
        searchController.searchResultsUpdater = self
        searchController.obscuresBackgroundDuringPresentation = false
        searchController.searchBar.placeholder = "Search Documents"
        navigationItem.searchController = searchController
        definesPresentationContext = true
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
        self.sections = sectionsAll
        applySnapshot()
    }
    
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchActive = false
    }
    
    func searchBarShouldEndEditing(_ searchBar: UISearchBar) -> Bool {
        return true
    }
    
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        
        self.searchActive = true;
        self.searchBar.showsCancelButton = true
        if searchText.isEmpty {
            sections = self.sectionsAll
            applySnapshot()
        }
        else {
            DispatchQueue.global(qos: .background).async {
                let toShow = self.sectionsAll.filter { section in
                    var matches = section.documentType.rawValue.lowercased().contains(searchText.lowercased())
                    for doc in section.documents {
                        if doc.title.lowercased().contains(searchText.lowercased()) {
                            matches = true
                            break
                        }
                    }
                    return matches
                }
                DispatchQueue.main.async {
                    self.sections = toShow
                    self.applySnapshot()
                }
            }
        }
    }
}

//
//  DocumentsViewControllerCollectionViewController.swift
//  Sketchnoting
//
//  Created by Aryobarzan on 29/11/2019.
//  Copyright © 2019 Aryobarzan. All rights reserved.
//

import UIKit
import Repeat
import ViewAnimator

private let reuseIdentifier = "cell"

class DocumentsViewController: UICollectionViewController{
    
    var items : [Document]!
    var sketchnote: Sketchnote!
    
    private var header: DocumentsCollectionReusableView?
        
    var selectedTopicDocuments: [Document]?
    
    var bookshelfUpdateTimer: Repeater?
    
    var bookshelfState = BookshelfState.All
    var bookshelfFilter = BookshelfFilter.All
    
    var documentDetailVC: DocumentDetailViewController!
    
    var delegate: DocumentsViewControllerDelegate?

    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.items = [Document]()
        
        let storyboard = UIStoryboard(name: "Main", bundle: Bundle.main)
        self.documentDetailVC = storyboard.instantiateViewController(withIdentifier: "DocumentDetailViewController") as? DocumentDetailViewController
        addChild(documentDetailVC)
        self.view.addSubview(documentDetailVC.view)
        documentDetailVC.view.frame = self.view.bounds
        documentDetailVC.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        documentDetailVC.didMove(toParent: self)
        documentDetailVC.view.isHidden = true
   }
    
    public func setNote(sketchnote: Sketchnote) {
        self.sketchnote = sketchnote
        self.items = sketchnote.documents
        self.updateBookshelf()
    }
    
    // MARK: UICollectionViewDataSource


    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return self.items.count
    }
    
    override func collectionView(_ collectionView: UICollectionView,
                                 viewForSupplementaryElementOfKind kind: String,
                                 at indexPath: IndexPath) -> UICollectionReusableView {
      // 1
      switch kind {
      // 2
      case UICollectionView.elementKindSectionHeader:
        // 3
        guard
          let headerView = collectionView.dequeueReusableSupplementaryView(
            ofKind: kind,
            withReuseIdentifier: "\(DocumentsCollectionReusableView.self)",
            for: indexPath) as? DocumentsCollectionReusableView
          else {
            fatalError("Invalid view type")
        }
        self.header = headerView
        header?.clearFilterButton.addTarget(self, action: #selector(clearFilterTapped(_:)), for: .touchUpInside)
        return headerView
      default:
        // 4
        assert(false, "Invalid element type")
      }
    }

    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: reuseIdentifier, for: indexPath as IndexPath) as! DocumentViewCell
        let document = self.items[indexPath.item]
        cell.document = document
        cell.titleLabel.text = document.title
        cell.previewImage.image = document.previewImage
        cell.previewImage.layer.masksToBounds = true
        cell.previewImage.layer.cornerRadius = 90
        switch document.documentType {
            
        case .Spotlight:
            cell.previewImage.layer.borderColor = #colorLiteral(red: 0.1764705926, green: 0.01176470611, blue: 0.5607843399, alpha: 1)
            break
        case .TAGME:
            cell.previewImage.layer.borderColor = #colorLiteral(red: 0.1764705926, green: 0.4980392158, blue: 0.7568627596, alpha: 1)
            break
        case .BioPortal:
            cell.previewImage.layer.borderColor = #colorLiteral(red: 0.3411764801, green: 0.6235294342, blue: 0.1686274558, alpha: 1)
            break
        case .Chemistry:
            cell.previewImage.layer.borderColor = #colorLiteral(red: 0.9529411793, green: 0.6862745285, blue: 0.1333333403, alpha: 1)
            break
        case .Other:
            cell.previewImage.layer.borderColor = #colorLiteral(red: 0.6000000238, green: 0.6000000238, blue: 0.6000000238, alpha: 1)
            break
        }
        cell.previewImage.layer.borderWidth = 3
        
        cell.layer.cornerRadius = 2
        
        return cell
    }

    // MARK: UICollectionViewDelegate
    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        documentDetailVC.setDocument(document: items[indexPath.item])
        documentDetailVC.view.isHidden = false
        let animation = AnimationType.from(direction: .right, offset: 100.0)
        documentDetailVC.view.animate(animations: [animation])
        
    }
    
    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        sizeForItemAt indexPath: IndexPath) -> CGSize {
        return CGSize(width: CGFloat(220), height: CGFloat(240))
    }

    func updateBookshelf() {
        DispatchQueue.main.async {
            if self.bookshelfState == .All {
                print("Updating Bookshelf.")
                self.header?.clearFilterButton.isHidden = true
                self.items = self.getFilteredDocuments(documents: self.sketchnote.documents)
                
                self.collectionView.reloadData()
            }
            else if self.bookshelfState == .Topic {
                if self.selectedTopicDocuments != nil {
                    self.header?.clearFilterButton.isHidden = false
                    self.items = self.getFilteredDocuments(documents: self.selectedTopicDocuments!)
                }
                else {
                    self.items = [Document]()
                }
                self.collectionView.reloadData()
            }
            
            self.updateBookshelfState(state: self.bookshelfState)
        }
    }
    
    func updateBookshelfState(state: BookshelfState) {
        self.bookshelfState = state
        switch self.bookshelfState {
        case .All:
            self.header?.clearFilterButton.isHidden = true
            self.selectedTopicDocuments = nil
        case .Topic:
            self.header?.clearFilterButton.isHidden = false
        }
    }
    
    private func getFilteredDocuments(documents: [Document]) -> [Document] {
        switch self.bookshelfFilter {
        case .All:
            return documents
        case .TAGME:
            return documents.filter{ $0.documentType == .TAGME }
        case .Spotlight:
            return documents.filter{ $0.documentType == .Spotlight }
        case .BioPortal:
            return documents.filter{ $0.documentType == .BioPortal }
        case .CHEBI:
            return documents.filter{ $0.documentType == .Chemistry }
        }
    }
    
    
    func startBookshelfUpdateTimer() {
        DispatchQueue.main.async {
            self.header?.updateActivityIndicator.isHidden = false
            if !(self.header?.updateActivityIndicator.isAnimating ?? true) {
                self.header?.updateActivityIndicator.startAnimating()
            }
            if self.bookshelfUpdateTimer != nil {
                log.info("Bookshelf Update Timer reset.")
                self.bookshelfUpdateTimer!.reset(nil)
            }
            else {
                log.info("Bookshelf Update Timer started.")
                self.bookshelfUpdateTimer = Repeater.once(after: .seconds(2)) { timer in
                    DispatchQueue.main.async {
                        self.updateBookshelf()
                        self.header?.updateActivityIndicator.stopAnimating()
                        self.header?.updateActivityIndicator.isHidden = true
                    }
                    
                }
            }
        }
    }
    
    override func collectionView(_ collectionView: UICollectionView, contextMenuConfigurationForItemAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
        return UIContextMenuConfiguration(identifier: nil, previewProvider: nil, actionProvider: { suggestedActions in
            return self.makeDocumentContextMenu(document: self.items[indexPath.row])
        })
    }
    private func makeDocumentContextMenu(document: Document) -> UIMenu {
        let hideAction = UIAction(title: "Hide", image: UIImage(systemName: "eye.slash")) { action in
            self.sketchnote.removeDocument(document: document)
            DocumentsManager.hide(document: document)
            if self.bookshelfState == .Topic {
                if self.selectedTopicDocuments != nil && self.selectedTopicDocuments!.contains(document) {
                    self.selectedTopicDocuments!.removeAll{$0 == document}
                }
            }
            self.updateBookshelf()
            //self.clearConceptHighlights()
            //if self.topicsShown {
            //    self.topicsShown = false
            //}
            //self.setupConceptHighlights()
        }
        return UIMenu(title: document.title, children: [hideAction])
    }
    
    func showTopicDocuments(documents: [Document]) {
        documentDetailVC.view.isHidden = true
        self.items = getFilteredDocuments(documents: documents)
        self.collectionView.reloadData()
        if bookshelfUpdateTimer != nil {
            bookshelfUpdateTimer!.reset(nil)
        }
        self.header?.clearFilterButton.isHidden = false
    }

    func clearTopicDocuments() {
        self.updateBookshelfState(state: .All)
        self.updateBookshelf()
    }
    
    func sketchnoteHasNewDocument(sketchnote: Sketchnote, document: Document) { // Sketchnote delegate
        DispatchQueue.main.async {
            if self.bookshelfState == .All && self.documentTypeMatchesBookshelfFilter(type: document.documentType) {
                CATransaction.begin()
                CATransaction.setDisableActions(true)
                self.items.append(document)
                let indexPath = IndexPath(row: self.items.count - 1, section: 0)
                self.collectionView.insertItems(at: [indexPath])
                CATransaction.commit()
                self.collectionView.scrollToItem(at: indexPath, at: .bottom , animated: true)
            }
            //self.topicsBadgeHub.setCount(self.sketchnote.documents.count)
        }
    }
    
    private func documentTypeMatchesBookshelfFilter(type: DocumentType) -> Bool {
        if self.bookshelfFilter == .All {
            return true
        }
        switch type {
        case .Spotlight:
            if self.bookshelfFilter == .Spotlight {
                return true
            }
        case .TAGME:
            if self.bookshelfFilter == .TAGME {
                return true
            }
        case .BioPortal:
            if self.bookshelfFilter == .BioPortal {
                return true
            }
        case .Chemistry:
            if self.bookshelfFilter == .CHEBI {
                return true
            }
        case .Other:
            return true
        }
        return false
    }
    
    func sketchnoteHasRemovedDocument(sketchnote: Sketchnote, document: Document) { // Sketchnote delegate
        self.startBookshelfUpdateTimer()
    }
    
    func sketchnoteDocumentHasChanged(sketchnote: Sketchnote, document: Document) { // Sketchnote delegate
        self.startBookshelfUpdateTimer()
    }
    
    func sketchnoteHasChanged(sketchnote: Sketchnote) { // Sketchnote delegate
    }
    
    func setFilter(option: BookshelfOption) {
        switch option {
        case .FilterAll:
            self.bookshelfFilter = .All
            self.updateBookshelf()
            break
        case .FilterTAGME:
            self.bookshelfFilter = .TAGME
            self.updateBookshelf()
            break
        case .FilterSpotlight:
            self.bookshelfFilter = .Spotlight
            self.updateBookshelf()
            break
        case .FilterBioPortal:
            self.bookshelfFilter = .BioPortal
            self.updateBookshelf()
            break
        case .FilterCHEBI:
            self.bookshelfFilter = .CHEBI
            self.updateBookshelf()
            break
        case .ResetDocuments:
            self.resetDocuments()
            break
        }
    }
    
    private func resetDocuments() {
        self.sketchnote.documents = [Document]()
        self.updateBookshelfState(state: .All)
        self.bookshelfFilter = .All
        self.updateBookshelf()
        self.delegate?.resetDocuments()
    }

    @objc func clearFilterTapped(_ sender: UIButton) {
        header?.clearFilterButton.isHidden = true
        clearTopicDocuments()
    }
}


public enum BookshelfFilter {
    case All
    case TAGME
    case Spotlight
    case BioPortal
    case CHEBI
}
public enum BookshelfState {
    case All
    case Topic
}

protocol DocumentsViewControllerDelegate  {
    func resetDocuments()
}

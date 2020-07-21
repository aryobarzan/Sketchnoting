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
import PopMenu

private let reuseIdentifier = "cell"

class DocumentsViewController: UICollectionViewController{
    
    var items : [Document]!
    var note: (URL, Note)!
    
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
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        super.prepare(for: segue, sender: sender)
        switch(segue.identifier ?? "") {
        default:
            log.info("Unaccounted-for segue.")
        }
    }
    
    public func setNote(url: URL, note: Note) {
        self.note = (url, note)
        self.items = note.getDocuments()
        self.updateBookshelf()
    }
    
    public func clear() {
        self.note.1.clearDocuments()
        self.items = self.note.1.getDocuments()
        self.updateBookshelf()
    }
    
    // MARK: UICollectionViewDataSource
    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return self.items.count
    }
    
    override func collectionView(_ collectionView: UICollectionView,
                                 viewForSupplementaryElementOfKind kind: String,
                                 at indexPath: IndexPath) -> UICollectionReusableView {
      switch kind {
      case UICollectionView.elementKindSectionHeader:
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
        cell.titleLabel.text = document.title
        cell.descriptionLabel.text = document.description
        cell.previewImage.image = UIImage(systemName: "questionmark.circle.fill")
        document.retrieveImage(type: .Standard, completion: { result in
            switch result {
            case .success(let value):
                if let value = value {
                    DispatchQueue.main.async {
                        cell.previewImage.image = value
                    }
                }
            case .failure(_):
                log.error("No preview image found for document \(document.title).")
            }
        })
        switch document.documentType {
        case .TAGME:
            cell.typeImage.tintColor = #colorLiteral(red: 0.1764705926, green: 0.4980392158, blue: 0.7568627596, alpha: 1)
            break
        case .WAT:
            cell.typeImage.tintColor = #colorLiteral(red: 0.8549019694, green: 0.250980407, blue: 0.4784313738, alpha: 1)
            break
        case .BioPortal:
            cell.typeImage.tintColor = #colorLiteral(red: 0.3411764801, green: 0.6235294342, blue: 0.1686274558, alpha: 1)
            break
        case .Chemistry:
            cell.typeImage.tintColor = #colorLiteral(red: 0.9529411793, green: 0.6862745285, blue: 0.1333333403, alpha: 1)
            break
        case .ALMAAR:
            cell.typeImage.tintColor = #colorLiteral(red: 0.9254902005, green: 0.2352941185, blue: 0.1019607857, alpha: 1)
            break
        case .Other:
            cell.typeImage.tintColor = #colorLiteral(red: 0.6000000238, green: 0.6000000238, blue: 0.6000000238, alpha: 1)
            break
        }
        cell.layer.borderColor = UIColor.lightGray.cgColor
        cell.layer.borderWidth = 1
        cell.layer.cornerRadius = 20.0
        cell.layer.shadowColor = UIColor.black.cgColor
        cell.layer.shadowOffset = .zero
        cell.layer.shadowRadius = 12.0
        cell.layer.shadowOpacity = 0.7
        cell.layer.shadowPath = UIBezierPath(rect: cell.bounds).cgPath
        cell.layer.shouldRasterize = true
        cell.layer.rasterizationScale = UIScreen.main.scale
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
        return CGSize(width: CGFloat(333), height: CGFloat(274))
    }

    func updateBookshelf() {
        DispatchQueue.main.async {
            if self.bookshelfState == .All {
                log.info("Updating Bookshelf.")
                self.header?.clearFilterButton.isHidden = true
                self.items = self.getFilteredDocuments(documents: self.note.1.getDocuments())
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
        case .WAT:
            return documents.filter{ $0.documentType == .WAT }
        case .BioPortal:
            return documents.filter{ $0.documentType == .BioPortal }
        case .CHEBI:
            return documents.filter{ $0.documentType == .Chemistry }
        case .ALMAAR:
            return documents.filter{ $0.documentType == .ALMAAR }
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
        let subConceptsAction = UIAction(title: "Subconcepts", image: UIImage(systemName: "doc.text.magnifyingglass")) { action in
            if let document = document as? TAGMEDocument {
                TAGMEHelper.shared.checkForSubconcepts(document: document, note: self.note)
            }
        }
        let hideAction = UIAction(title: "Hide", image: UIImage(systemName: "eye.slash")) { action in
            self.note.1.hide(document: document)
            if self.bookshelfState == .Topic {
                if self.selectedTopicDocuments != nil && self.selectedTopicDocuments!.contains(document) {
                    self.selectedTopicDocuments!.removeAll{$0 == document}
                }
            }
            self.updateBookshelf()
            self.delegate?.updateTopicsCount()
        }
        return UIMenu(title: document.title, children: [subConceptsAction, hideAction])
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
    
    func noteHasNewDocument(note: Note, document: Document) { // Sketchnote delegate
        DispatchQueue.main.async {
            if self.bookshelfState == .All && self.documentTypeMatchesBookshelfFilter(type: document.documentType) {
                self.items.append(document)
                let indexPath = IndexPath(item: self.items.count - 1, section: 0)
                self.collectionView.performBatchUpdates({ () -> Void in
                    self.collectionView.insertItems(at: [indexPath])
                }, completion: nil)
            }
            self.delegate?.updateTopicsCount()
        }
    }
    
    private func documentTypeMatchesBookshelfFilter(type: DocumentType) -> Bool {
        if self.bookshelfFilter == .All {
            return true
        }
        switch type {
        case .TAGME:
            if self.bookshelfFilter == .TAGME {
                return true
            }
        case .WAT:
            if self.bookshelfFilter == .WAT {
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
        case .ALMAAR:
            if self.bookshelfFilter == .ALMAAR {
            return true
            }
        case .Other:
            return true
        }
        return false
    }
    
    func noteHasRemovedDocument(note: Note, document: Document) { // Sketchnote delegate
        self.startBookshelfUpdateTimer()
    }
    
    func noteDocumentHasChanged(note: Note, document: Document) { // Sketchnote delegate
        self.startBookshelfUpdateTimer()
    }
    
    func noteHasChanged(note: Note) { // Sketchnote delegate
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
        self.note.1.clearDocuments()
        self.updateBookshelfState(state: .All)
        self.bookshelfFilter = .All
        self.updateBookshelf()
        self.delegate?.resetDocuments()
    }

    @objc func clearFilterTapped(_ sender: UIButton) {
        header?.clearFilterButton.isHidden = true
        clearTopicDocuments()
    }
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
            }))
            
            title = "Balanced"
            if self.note.1.tagmeEpsilon == Float(0.3) {
                title = "✔︎ Balanced"
            }
            alert.addAction(UIAlertAction(title: NSLocalizedString(title, comment: ""), style: .default, handler: { _ in
                self.note.1.tagmeEpsilon = 0.3
            }))
            
            title = "Favor Contextual Topics (Less)"
            if self.note.1.tagmeEpsilon == Float(0.5) {
                title = "✔︎ Favor Contextual Topics (Less)"
            }
            alert.addAction(UIAlertAction(title: NSLocalizedString(title, comment: ""), style: .default, handler: { _ in
                self.note.1.tagmeEpsilon = 0.5
            }))
            self.present(alert, animated: true, completion: nil)
        })
        popMenu.addAction(tagmeEpsilonAction)
        let resetAction = PopMenuDefaultAction(title: "Reset Documents", image: UIImage(systemName: "wand.and.rays"),  didSelect: { action in
            self.resetDocuments()
        })
        popMenu.addAction(resetAction)
        let hiddenDocumentsAction = PopMenuDefaultAction(title: "Manage Hidden Documents", image: UIImage(systemName: "eye.slash"),  didSelect: { action in
            popMenu.dismiss(animated: true, completion: nil)
            self.performSegue(withIdentifier: "ManageHiddenDocuments", sender: self)
        })
        popMenu.addAction(hiddenDocumentsAction)
        self.present(popMenu, animated: true, completion: nil)
    }
    
    @IBAction func filterTapped(_ sender: UIButton) {
        let popMenu = PopMenuViewController(sourceView: sender, actions: [PopMenuAction](), appearance: nil)
        popMenu.appearance.popMenuBackgroundStyle = .none()
        
        var allImage: UIImage? = nil
        var tagmeImage: UIImage? = nil
        var watImage: UIImage? = nil
        var bioportalImage: UIImage? = nil
        var chebiImage: UIImage? = nil
        var almaarImage: UIImage? = nil
        switch self.bookshelfFilter {
        case .All:
            allImage = UIImage(systemName: "checkmark.circle.fill")
            break
        case .TAGME:
            tagmeImage = UIImage(systemName: "checkmark.circle.fill")
            break
        case .WAT:
            watImage = UIImage(systemName: "checkmark.circle.fill")
            break
        case .BioPortal:
            bioportalImage = UIImage(systemName: "checkmark.circle.fill")
            break
        case .CHEBI:
            chebiImage = UIImage(systemName: "checkmark.circle.fill")
            break
        case .ALMAAR:
            almaarImage = UIImage(systemName: "checkmark.circle.fill")
        break
        }
        let allAction = PopMenuDefaultAction(title: "All", image: allImage,  didSelect: { action in
            self.bookshelfFilter = .All
            self.updateBookshelf()
            
        })
        popMenu.addAction(allAction)
        let tagmeAction = PopMenuDefaultAction(title: "TAGME", image: tagmeImage, didSelect: { action in
            self.bookshelfFilter = .TAGME
            self.updateBookshelf()
        })
        popMenu.addAction(tagmeAction)
        let watAction = PopMenuDefaultAction(title: "WAT", image: watImage, didSelect: { action in
            self.bookshelfFilter = .WAT
            self.updateBookshelf()
        })
        popMenu.addAction(watAction)
        let bioportalAction = PopMenuDefaultAction(title: "BioPortal", image: bioportalImage, didSelect: { action in
            self.bookshelfFilter = .BioPortal
            self.updateBookshelf()
        })
        popMenu.addAction(bioportalAction)
        let chebiAction = PopMenuDefaultAction(title: "CHEBI", image: chebiImage, didSelect: { action in
            self.bookshelfFilter = .CHEBI
            self.updateBookshelf()
        })
        popMenu.addAction(chebiAction)
        let almaarAction = PopMenuDefaultAction(title: "AR", image: almaarImage, didSelect: { action in
            self.bookshelfFilter = .ALMAAR
            self.updateBookshelf()
        })
        popMenu.addAction(almaarAction)
        
        self.present(popMenu, animated: true, completion: nil)
    }
}


public enum BookshelfFilter {
    case All
    case TAGME
    case WAT
    case BioPortal
    case ALMAAR
    case CHEBI
}
public enum BookshelfState {
    case All
    case Topic
}

enum BookshelfOption {
    case FilterAll
    case FilterTAGME
    case FilterBioPortal
    case FilterCHEBI
    case ResetDocuments
}


protocol DocumentsViewControllerDelegate  {
    func resetDocuments()
    func updateTopicsCount()
}

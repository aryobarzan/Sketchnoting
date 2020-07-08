//
//  NotePagesViewController.swift
//  Sketchnoting
//
//  Created by Aryobarzan on 14/12/2019.
//  Copyright © 2019 Aryobarzan. All rights reserved.
//

import UIKit

class NotePagesViewController: UIViewController, UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout, UICollectionViewDragDelegate, UICollectionViewDropDelegate {

    @IBOutlet weak var collectionView: UICollectionView!
    var delegate: NotePagesDelegate?
    
    var note: (URL, Note)!
    
    @IBOutlet weak var pageButton: UIBarButtonItem!
    override func viewDidLoad() {
        super.viewDidLoad()

        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.dragDelegate = self
        collectionView.dropDelegate = self
        collectionView.dragInteractionEnabled = true
        
        pageButton.title = "Page \(note.1.activePageIndex+1)"
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        collectionView.reloadData()
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return note.1.pages.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "NotePageCell", for: indexPath as IndexPath) as! NotePageCollectionViewCell
        let page = note.1.pages[indexPath.item]
        page.getAsImage() { image in
            cell.imageView.image = image
        }
        cell.pageIndexLabel.text = "\(indexPath.item + 1)"
        cell.imageView.layer.cornerRadius = 4
        cell.imageView.layer.borderWidth = 2
        if indexPath.item == note.1.activePageIndex {
            cell.imageView.layer.borderColor = UIColor.systemBlue.cgColor
        }
        else {
            cell.imageView.layer.borderColor = UIColor.clear.cgColor
        }
        return cell
    }
    
    // MARK: UICollectionViewDelegate
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        delegate?.notePageSelected(index: indexPath.item)
        self.dismiss(animated: true, completion: nil)
    }
    
    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        sizeForItemAt indexPath: IndexPath) -> CGSize {
        return CGSize(width: CGFloat(180), height: CGFloat(265))
    }
    
    // Drag and drop delegates for re-ordering
    func collectionView(_ collectionView: UICollectionView, itemsForBeginning session: UIDragSession, at indexPath: IndexPath) -> [UIDragItem] {
        let item = note.1.pages[indexPath.row]
        let itemProvider = NSItemProvider(object: item.getText() as NSString)
        let dragItem = UIDragItem(itemProvider: itemProvider)
        return [dragItem]
    }
    
    func collectionView(_ collectionView: UICollectionView,
                        canHandle session: UIDropSession) -> Bool {
      return true
    }
    
    func collectionView(_ collectionView: UICollectionView, performDropWith coordinator: UICollectionViewDropCoordinator) {
        guard let destinationIndexPath = coordinator.destinationIndexPath else {
          return
        }
        
        coordinator.items.forEach { dropItem in
          guard let sourceIndexPath = dropItem.sourceIndexPath else {
            return
          }

          collectionView.performBatchUpdates({
            let page = note.1.pages[sourceIndexPath.item]
            if note.1.activePageIndex == sourceIndexPath.item {
                note.1.activePageIndex = destinationIndexPath.item
            }
            note.1.removePage(at: sourceIndexPath)
            note.1.insertPage(page, at: destinationIndexPath)
            collectionView.deleteItems(at: [sourceIndexPath])
            collectionView.insertItems(at: [destinationIndexPath])
            NeoLibrary.save(note: note.1, url: note.0)
          }, completion: { _ in
            coordinator.drop(dropItem.dragItem,
                              toItemAt: destinationIndexPath)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                collectionView.reloadData()
                self.delegate?.notePagesReordered(note: self.note.1)
            }
          })
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, dropSessionDidUpdate session: UIDropSession, withDestinationIndexPath destinationIndexPath: IndexPath?) -> UICollectionViewDropProposal {
      return UICollectionViewDropProposal(operation: .move, intent: .insertAtDestinationIndexPath)
    }
    @IBAction func pageButtonTapped(_ sender: UIBarButtonItem) {
        self.showInputDialog(title: "Go to page:", subtitle: nil, actionTitle: "Go", cancelTitle: "Cancel", inputPlaceholder: "Page Number", inputKeyboardType: .numberPad, cancelHandler: nil)
        { (input:String?) in
            if input != nil && Int(input!) != nil {
                if let pageNumber = Int(input!) {
                    if (pageNumber - 1) >= 0 && (pageNumber - 1) < self.note.1.pages.count && (pageNumber - 1) != self.note.1.activePageIndex {
                        self.delegate?.notePageSelected(index: pageNumber - 1)
                        self.dismiss(animated: true, completion: nil)
                    }
                }
            }
        }
    }
    
    @IBAction func doneTapped(_ sender: UIBarButtonItem) {
        self.dismiss(animated: true)
    }
    
    func collectionView(_ collectionView: UICollectionView, contextMenuConfigurationForItemAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
        return UIContextMenuConfiguration(identifier: nil, previewProvider: nil, actionProvider: { suggestedActions in
            return self.makeDocumentContextMenu(pageIndex: indexPath.row)
        })
    }
    private func makeDocumentContextMenu(pageIndex: Int) -> UIMenu {
        let copyAction = UIAction(title: "Copy", image: UIImage(systemName: "doc.text")) { action in
            SKClipboard.copy(page: self.note.1.pages[pageIndex])
            self.view.makeToast("Copied page to SKClipboard.")
        }
        let deleteAction = UIAction(title: "Delete", image: UIImage(systemName: "trash")) { action in
            let isDeleted = self.note.1.deletePage(index: pageIndex)
            if isDeleted {
                self.delegate?.notePageDeleted(note: self.note.1)
            }
            self.collectionView.reloadData()
        }
        return UIMenu(title: "Note Page", children: [copyAction, deleteAction])
    }
}

protocol NotePagesDelegate {
    func notePageSelected(index: Int)
    func notePagesReordered(note: Note)
    func notePageDeleted(note: Note)
}

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
    
    override func viewDidLoad() {
        super.viewDidLoad()

        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.dragDelegate = self
        collectionView.dropDelegate = self
        collectionView.dragInteractionEnabled = true
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        collectionView.reloadData()
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return NotesManager.activeNote!.pages.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "NotePageCell", for: indexPath as IndexPath) as! NotePageCollectionViewCell
        let page = NotesManager.activeNote!.pages[indexPath.item]
        cell.imageView.image = page.image
        cell.pageIndexLabel.text = "\(indexPath.item)"
        cell.imageView.layer.cornerRadius = 4
        cell.imageView.layer.borderWidth = 2
        if page == NotesManager.activeNote!.getCurrentPage() {
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
        let item = NotesManager.activeNote!.pages[indexPath.row]
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
            let page = NotesManager.activeNote!.pages[sourceIndexPath.item]
            if NotesManager.activeNote!.activePageIndex == sourceIndexPath.item {
                NotesManager.activeNote!.activePageIndex = destinationIndexPath.item
            }
            NotesManager.activeNote!.removePage(at: sourceIndexPath)
            NotesManager.activeNote!.insertPage(page, at: destinationIndexPath)
            collectionView.deleteItems(at: [sourceIndexPath])
            collectionView.insertItems(at: [destinationIndexPath])
            NotesManager.activeNote!.save()
          }, completion: { _ in
            coordinator.drop(dropItem.dragItem,
                              toItemAt: destinationIndexPath)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                collectionView.reloadData()
                self.delegate?.notePagesReordered()
            }
          })
        }
    }
    
    func collectionView(
      _ collectionView: UICollectionView,
      dropSessionDidUpdate session: UIDropSession,
      withDestinationIndexPath destinationIndexPath: IndexPath?)
      -> UICollectionViewDropProposal {
      return UICollectionViewDropProposal(
        operation: .move,
        intent: .insertAtDestinationIndexPath)
    }
    
    

}

protocol NotePagesDelegate {
    func notePageSelected(index: Int)
    func notePagesReordered()
}

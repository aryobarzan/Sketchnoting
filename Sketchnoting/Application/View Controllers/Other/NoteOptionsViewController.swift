//
//  NoteOptionsViewController.swift
//  Sketchnoting
//
//  Created by Aryobarzan on 28/06/2020.
//  Copyright © 2020 Aryobarzan. All rights reserved.
//

import UIKit

import ViewAnimator

enum NoteOption: String, Codable {
    case Annotate = "Annotate"
    case RelatedNotes = "Related Notes"
    case ViewText = "View Text"
    case CopyText = "Copy Text"
    case CopyNote = "Copy Note"
    case MoveFile = "Move"
    case DeletePage = "Delete Page"
    case Export = "Export"
    case ResetTextRecognition = "Reset Text Recognition"
    case DeleteNote = "Delete Note"
    case HelpLines = "Help Lines"
}
struct NoteOptionWrapper: Codable {
    let option: NoteOption
    let image: String
    let isDestructive: Bool
    let isInstantAction: Bool
    let isToggle: Bool
}

class NoteOptionsViewController: UIViewController, UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout, UICollectionViewDragDelegate, UICollectionViewDropDelegate {
    
    @IBOutlet weak var collectionView: UICollectionView!
    var delegate: NoteOptionsDelegate?
    var note: (URL, Note)!
    
    private var options: [NoteOptionWrapper] = [
                                              NoteOptionWrapper(option: .Annotate, image: "wand.and.rays", isDestructive: false, isInstantAction: true, isToggle: false),
                                              NoteOptionWrapper(option: .RelatedNotes, image: "link", isDestructive: false, isInstantAction: false, isToggle: false),
                                              NoteOptionWrapper(option: .ViewText, image: "text.alignleft", isDestructive: false, isInstantAction: false, isToggle: false),
                                              NoteOptionWrapper(option: .CopyText, image: "text.quote", isDestructive: false, isInstantAction: true, isToggle: false),
                                              NoteOptionWrapper(option: .CopyNote, image: "doc.circle", isDestructive: false, isInstantAction: true, isToggle: false),
                                              NoteOptionWrapper(option: .MoveFile, image: "folder", isDestructive: false, isInstantAction: false, isToggle: false),
                                              NoteOptionWrapper(option: .DeletePage, image: "text.badge.minus", isDestructive: true, isInstantAction: false, isToggle: false),
                                              NoteOptionWrapper(option: .Export, image: "square.and.arrow.up", isDestructive: false, isInstantAction: false, isToggle: false),
                                              NoteOptionWrapper(option: .ResetTextRecognition, image: "pencil.and.outline", isDestructive: false, isInstantAction: true, isToggle: false),
                                              NoteOptionWrapper(option: .DeleteNote, image: "trash", isDestructive: true, isInstantAction: false, isToggle: false),
                                              NoteOptionWrapper(option: .HelpLines, image: "line.horizontal.3", isDestructive: false, isInstantAction: true, isToggle: true)
                                              ]

    override func viewDidLoad() {
        super.viewDidLoad()
        
        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.dragDelegate = self
        collectionView.dropDelegate = self
        collectionView.dragInteractionEnabled = true
        
        if let noteOptionsOrdering = SettingsManager.getNoteOptionsOrdering() {
            var optionsTemp = [NoteOptionWrapper]()
            var unorderedTemp = [NoteOptionWrapper]()
            for option in self.options {
                if let indexOfOption = noteOptionsOrdering[option.option] {
                    if optionsTemp.count < indexOfOption {
                        optionsTemp.append(option)
                    }
                    else {
                       optionsTemp.insert(option, at: indexOfOption)
                    }
                }
                else {
                    unorderedTemp.append(option)
                }
            }
            self.options = optionsTemp + unorderedTemp
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        collectionView.reloadData()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return self.options.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "NoteOptionViewCell", for: indexPath as IndexPath) as! NoteOptionsCollectionViewCell
        let option = self.options[indexPath.item]
        cell.set(option: option)
        return cell
    }
    
    // MARK: UICollectionViewDelegate
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let option = self.options[indexPath.item]
        if !option.isToggle {
            self.dismiss(animated: true, completion: nil)
            delegate?.noteOptionSelected(option: self.options[indexPath.item].option)
        }
        else {
            delegate?.noteOptionSelected(option: self.options[indexPath.item].option)
            self.collectionView.performBatchUpdates({
                self.collectionView.reloadItems(at: [indexPath])
            })
        }
    }
    
    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        sizeForItemAt indexPath: IndexPath) -> CGSize {
        return CGSize(width: CGFloat(75), height: CGFloat(75))
    }
    
    // Drag and drop delegates for re-ordering
    func collectionView(_ collectionView: UICollectionView, itemsForBeginning session: UIDragSession, at indexPath: IndexPath) -> [UIDragItem] {
        let option = self.options[indexPath.row]
        let itemProvider = NSItemProvider(object: option.option.rawValue as NSString)
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
            let option = self.options[sourceIndexPath.item]
            self.options.remove(at: sourceIndexPath.item)
            self.options.insert(option, at: destinationIndexPath.item)
            collectionView.deleteItems(at: [sourceIndexPath])
            collectionView.insertItems(at: [destinationIndexPath])
          }, completion: { _ in
            coordinator.drop(dropItem.dragItem,
                              toItemAt: destinationIndexPath)
            collectionView.reloadData()
            self.saveNoteOptionsOrdering()
          })
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, dropSessionDidUpdate session: UIDropSession, withDestinationIndexPath destinationIndexPath: IndexPath?) -> UICollectionViewDropProposal {
      return UICollectionViewDropProposal(operation: .move, intent: .insertAtDestinationIndexPath)
    }
    
    private func saveNoteOptionsOrdering() {
        var ordering = [NoteOption : Int]()
        for i in 0..<self.options.count {
            ordering[options[i].option] = i
        }

        SettingsManager.setNoteOptionsOrdering(orderingList: ordering)
    }

}


protocol NoteOptionsDelegate  {
    func noteOptionSelected(option: NoteOption)
}

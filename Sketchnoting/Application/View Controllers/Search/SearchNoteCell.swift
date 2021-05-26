//
//  SearchNoteCell.swift
//  Sketchnoting
//
//  Created by Aryobarzan on 02/04/2021.
//  Copyright © 2021 Aryobarzan. All rights reserved.
//

import UIKit

protocol SearchNoteCellDelegate {
    func tappedNote(url: URL, note: Note)
    func tappedExplainNoteResult(noteResult: SearchNoteResult)
}

class SearchNoteCell: UITableViewCell, UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var subtitleLabel: UILabel!
    @IBOutlet weak var collectionView: UICollectionView!
    
    var noteResults = [SearchNoteResult]()
    var delegate: SearchNoteCellDelegate?
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
        collectionView.register(UINib(nibName: "NoteCollectionViewCell", bundle: nil), forCellWithReuseIdentifier: "NoteCollectionViewCell")
        collectionView.delegate = self
        collectionView.dataSource = self
    }
    
    func setContent(query: String, noteResults: [SearchNoteResult]) {
        titleLabel.text = "Notes (\(Int(noteResults.count)))"
        subtitleLabel.text = "For search query: '\(query)'"
        self.noteResults = noteResults.sorted { note1, note2 in
            note1.noteScore > note2.noteScore
        }
        collectionView.reloadData()
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return noteResults.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "NoteCollectionViewCell", for: indexPath as IndexPath) as! NoteCollectionViewCell
        let (url, note, score) = (noteResults[indexPath.item].note.0, noteResults[indexPath.item].note.1, noteResults[indexPath.item].noteScore)
        cell.setFile(url: url, file: note, progress: score)
        cell.toggleSelectionMode(status: false)
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        sizeForItemAt indexPath: IndexPath) -> CGSize {
        return CGSize(width: CGFloat(200), height: CGFloat(300))
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let item = noteResults[indexPath.row]
        delegate?.tappedNote(url: item.note.0, note: item.note.1)
    }
    
    func collectionView(_ collectionView: UICollectionView, contextMenuConfigurationForItemAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
        return UIContextMenuConfiguration(identifier: nil, previewProvider: nil, actionProvider: { suggestedActions in
            return self.makeNoteContextMenu(point: point, cellIndexPath: indexPath)
        })
    }
    
    private func makeNoteContextMenu(point: CGPoint, cellIndexPath: IndexPath) -> UIMenu {
        let noteResult = self.noteResults[cellIndexPath.row]
        var menuElements = [UIMenuElement]()
        let showResultExplanationAction = UIAction(title: "Why this result?", image: UIImage(systemName: "questionmark.circle")) { action in
            self.delegate?.tappedExplainNoteResult(noteResult: noteResult)
        }
        menuElements.append(showResultExplanationAction)
        return UIMenu(title: noteResult.note.1.getName(), children: menuElements)
    }
}

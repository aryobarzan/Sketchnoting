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
}

class SearchNoteCell: UITableViewCell, UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var subtitleLabel: UILabel!
    @IBOutlet weak var collectionView: UICollectionView!
    
    var notes = [(URL, Note, Double)]()
    var delegate: SearchNoteCellDelegate?
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
        collectionView.register(UINib(nibName: "NoteCollectionViewCell", bundle: nil), forCellWithReuseIdentifier: "NoteCollectionViewCell")
        collectionView.delegate = self
        collectionView.dataSource = self
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
        // Configure the view for the selected state
    }
    
    func setContent(query: String, notes: [(URL, Note, Double)]) {
        titleLabel.text = "Notes (\(Int(notes.count)))"
        subtitleLabel.text = "For search query: '\(query)'"
        self.notes = notes.sorted { note1, note2 in
            note1.2 > note2.2
        }
        normalizeNoteSimilarities()
        collectionView.reloadData()
    }
    
    func normalizeNoteSimilarities() {
        if !notes.isEmpty {
            let maxSimilarity = notes.map{$0.2}.max()!
            let minSimilarity = 0.0 //notes.map{$0.2}.min()!
            self.notes = notes.map {($0.0, $0.1, ($0.2 - minSimilarity)/(maxSimilarity-minSimilarity))}
        }
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return notes.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "NoteCollectionViewCell", for: indexPath as IndexPath) as! NoteCollectionViewCell
        let (url, note, score) = (notes[indexPath.item].0, notes[indexPath.item].1, notes[indexPath.item].2)
        cell.setFile(url: url, file: note, progress: score)
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        sizeForItemAt indexPath: IndexPath) -> CGSize {
        return CGSize(width: CGFloat(200), height: CGFloat(300))
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let item = notes[indexPath.row]
        delegate?.tappedNote(url: item.0, note: item.1)
    }
}

//
//  SearchNotesCard.swift
//  Sketchnoting
//
//  Created by Aryobarzan on 01/04/2021.
//  Copyright © 2021 Aryobarzan. All rights reserved.
//

import UIKit

protocol SearchNotesCardDelegate {
    func noteTapped(url: URL, note: Note)
}

class SearchNotesCard: UIView, UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    let kCONTENT_XIB_NAME = "SearchNotesCard"

    @IBOutlet var contentView: SearchNotesCard!
    @IBOutlet weak var collectionView: UICollectionView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var closeButton: UIButton!
    
    var notes = [(URL, Note, Double)]()
    var delegate: SearchNotesCardDelegate?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        commonInit()
    }
    
    public init(query: String, notes: [(URL, Note, Double)], frame: CGRect) {
        super.init(frame: frame)
        Bundle.main.loadNibNamed(kCONTENT_XIB_NAME, owner: self, options: nil)
        contentView.fixInView(self)
        self.layer.borderWidth = 2
        self.layer.borderColor = UIColor.systemBlue.cgColor
        self.layer.masksToBounds = true
        
        collectionView.register(UINib(nibName: "NoteCollectionViewCell", bundle: nil), forCellWithReuseIdentifier: "NoteCollectionViewCell")
        collectionView.delegate = self
        collectionView.dataSource = self
        
        setContent(query: query, notes: notes)
        setNeedsLayout()
    }
    
    func commonInit() {
        Bundle.main.loadNibNamed(kCONTENT_XIB_NAME, owner: self, options: nil)
        contentView.fixInView(self)
    }
    
    func setContent(query: String, notes: [(URL, Note, Double)]) {
        titleLabel.text = "'\(query)'"
        self.notes = notes.sorted { note1, note2 in
            note1.2 > note2.2
        }
        collectionView.reloadData()
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
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        delegate?.noteTapped(url: self.notes[indexPath.item].0, note: self.notes[indexPath.item].1)
        logger.info("Note tapped.")
    }
    
    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        sizeForItemAt indexPath: IndexPath) -> CGSize {
        return CGSize(width: CGFloat(200), height: CGFloat(300))
    }
    
    @IBAction func closeTapped(_ sender: UIButton) {
        self.removeFromSuperview()
    }
}

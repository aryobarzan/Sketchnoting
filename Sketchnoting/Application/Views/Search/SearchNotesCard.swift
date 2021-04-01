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
    
    var notes = [(URL, Note)]()
    var delegate: SearchNotesCardDelegate?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        commonInit()
    }
    
    public init(query: String, notes: [(URL, Note)], frame: CGRect) {
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
    
    func setContent(query: String, notes: [(URL, Note)]) {
        titleLabel.text = "'\(query)'"
        self.notes = notes
        collectionView.reloadData()
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return notes.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "NoteCollectionViewCell", for: indexPath as IndexPath) as! NoteCollectionViewCell
        cell.setFile(url: notes[indexPath.item].0 ,file: notes[indexPath.item].1)
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        delegate?.noteTapped(url: self.notes[indexPath.item].0, note: self.notes[indexPath.item].1)
        logger.info("Note tapped.")
    }
    
    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        sizeForItemAt indexPath: IndexPath) -> CGSize {
        return CGSize(width: CGFloat(160), height: CGFloat(240))
    }
    
    @IBAction func closeTapped(_ sender: UIButton) {
        self.removeFromSuperview()
    }
}

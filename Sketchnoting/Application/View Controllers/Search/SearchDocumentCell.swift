//
//  SearchDocumentCell.swift
//  Sketchnoting
//
//  Created by Aryobarzan on 02/04/2021.
//  Copyright © 2021 Aryobarzan. All rights reserved.
//

import UIKit

protocol SearchDocumentCellDelegate {
    func documentTapped(document: Document)
}

class SearchDocumentCell: UITableViewCell, UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {

    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var subtitleLabel: UILabel!
    @IBOutlet weak var documentsCollectionView: UICollectionView!
    
    var documents = [(Document, Double)]()
    var delegate: SearchDocumentCellDelegate?
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        documentsCollectionView.register(UINib(nibName: "DocumentCollectionViewCell", bundle: nil), forCellWithReuseIdentifier: "DocumentCollectionViewCell")
        documentsCollectionView.delegate = self
        documentsCollectionView.dataSource = self
    }

    func setContent(query: String, documents: [(Document, Double)]) {
        self.documents = documents
        self.documents = documents.sorted { document1, document2 in
            document1.1 > document2.1
        }
        documentsCollectionView.reloadData()
        titleLabel.text = "Documents (\(Int(documents.count)))"
        subtitleLabel.text = "For search query: '\(query)'"
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return documents.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "DocumentCollectionViewCell", for: indexPath as IndexPath) as! DocumentCollectionViewCell
        cell.document = documents[indexPath.row].0
        cell.score = documents[indexPath.row].1
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        sizeForItemAt indexPath: IndexPath) -> CGSize {
        return CGSize(width: CGFloat(200), height: CGFloat(200))
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let document = documents[indexPath.row]
        delegate?.documentTapped(document: document.0)
    }
}

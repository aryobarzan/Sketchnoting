//
//  NotePagesViewController.swift
//  Sketchnoting
//
//  Created by Aryobarzan on 14/12/2019.
//  Copyright © 2019 Aryobarzan. All rights reserved.
//

import UIKit

class NotePagesViewController: UIViewController, UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {

    @IBOutlet weak var collectionView: UICollectionView!
    var delegate: NotePagesDelegate?
    
    override func viewDidLoad() {
        super.viewDidLoad()

        collectionView.delegate = self
        collectionView.dataSource = self
        // Do any additional setup after loading the view.
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

}

protocol NotePagesDelegate {
    func notePageSelected(index: Int)
}

//
//  SearchDocumentsCard.swift
//  Sketchnoting
//
//  Created by Aryobarzan on 23/02/2021.
//  Copyright © 2021 Aryobarzan. All rights reserved.
//

import UIKit

class SearchDocumentsCard: UIView {
    let kCONTENT_XIB_NAME = "SearchDocumentsCard"
        
    @IBOutlet var contentView: UIView!
    @IBOutlet var titleLabel: UILabel!
    @IBOutlet var imageView: UIImageView!
    @IBOutlet var bodyTextView: UITextView!
    @IBOutlet var imagePageControl: UIPageControl!
    @IBOutlet var documentIndexLabel: UILabel!
    @IBOutlet var previousDocumentButton: UIButton!
    @IBOutlet var nextDocumentButton: UIButton!
    
    var currentIndex = 0
    var documents: [Document] = [Document]()
    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        commonInit()
    }
    
    public init(documents: [Document], frame: CGRect) {
        super.init(frame: frame)
        Bundle.main.loadNibNamed(kCONTENT_XIB_NAME, owner: self, options: nil)
        contentView.fixInView(self)
        self.layer.masksToBounds = true
        
        setContent(documents: documents)
        setNeedsLayout()
        //self.closeButtonView.setNeedsLayout()
    }
    
    func commonInit() {
        Bundle.main.loadNibNamed(kCONTENT_XIB_NAME, owner: self, options: nil)
        contentView.fixInView(self)
    }
    
    func setContent(documents: [Document]) {
        self.documents = documents
        if documents.count > 0 {
            let firstDocument = documents[0]
            titleLabel.text = firstDocument.title
            bodyTextView.text = firstDocument.description
            firstDocument.retrieveImage(type: .Standard, completion: { result in
                switch result {
                case .success(let value):
                    if let image = value {
                        DispatchQueue.main.async {
                            self.imageView.image = image
                        }
                    }
                case .failure(_): break
                }
            })
            documentIndexLabel.text = "1 / \(documents.count)"
        }
    }
    
    @IBAction func previousDocumentButtonTapped(_ sender: UIButton) {
    }
    @IBAction func nextDocumentButtonTapped(_ sender: UIButton) {
    }
    @IBAction func imagePageControlChanged(_ sender: UIPageControl) {
    }
    @IBAction func imageViewTapped(_ sender: UITapGestureRecognizer) {
    }
    @IBAction func imageViewSwiped(_ sender: UISwipeGestureRecognizer) {
    }
}

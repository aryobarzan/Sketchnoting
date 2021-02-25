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
    @IBOutlet weak var documentIndexViewsContainer: UIView!
    @IBOutlet var documentIndexLabel: UILabel!
    @IBOutlet var previousDocumentButton: UIButton!
    @IBOutlet var nextDocumentButton: UIButton!

    var documents = [Document]()
    var images = [UIImage]()
    
    var currentIndex = 0
    var currentImageIndex = 0
    
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
        self.layer.borderWidth = 2
        self.layer.borderColor = UIColor.systemBlue.cgColor
        self.layer.masksToBounds = true
        
        imageView.layer.masksToBounds = true
        imageView.layer.cornerRadius = 64
        imageView.layer.borderWidth = 1
        imageView.layer.borderColor = UIColor.systemGray.cgColor
        imageView.tintColor = .gray
        imageView.isUserInteractionEnabled = true
        
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
        currentIndex = 0
        currentImageIndex = 0
        updateDisplayedDocument()
        updateDocumentIndex()
    }
    
    private func updateDisplayedDocument() {
        if !documents.isEmpty {
            let document = documents[currentIndex]
            titleLabel.text = document.title
            bodyTextView.text = document.description
        }
        fetchDocumentImages()
        updateDocumentIndex()
    }
    
    private func fetchDocumentImages() {
        if !documents.isEmpty {
            images = [UIImage]()
            let currentDocument = documents[currentIndex]
            currentDocument.retrieveImage(type: .Standard, completion: { result in
                switch result {
                case .success(let value):
                    if let image = value {
                        if self.images.isEmpty {
                            self.images.append(image)
                        }
                        else {
                            self.images.insert(image, at: 0)
                        }
                        self.updateImageView()
                        
                    }
                case .failure(_): break
                }
            })
            currentDocument.retrieveImage(type: .Map, completion: { result in
                switch result {
                case .success(let value):
                    if let image = value {
                        if self.images.isEmpty {
                            self.images.append(image)
                        }
                        else {
                            self.images.insert(image, at: 1)
                        }
                        self.updateImageView()
                        
                    }
                case .failure(_): break
                }
            })
        }
    }
    
    private func updateImageView() {
        DispatchQueue.main.async {
            self.imageView.image = nil
        }
        if !images.isEmpty {
            DispatchQueue.main.async {
                self.imageView.image = self.images[self.currentImageIndex]
            }
        }
        if images.count < 2 {
            DispatchQueue.main.async {
                self.imagePageControl.isHidden = true
            }
        }
        else {
            DispatchQueue.main.async {
                self.imagePageControl.isHidden = false
                self.imagePageControl.currentPage = self.currentImageIndex
            }
        }
    }
    
    private func updateDocumentIndex() {
        previousDocumentButton.isEnabled = true
        nextDocumentButton.isEnabled = true
        if documents.count < 2 {
            documentIndexViewsContainer.isHidden = true
        }
        else {
            documentIndexViewsContainer.isHidden = false
            if currentIndex == 0 {
                previousDocumentButton.isEnabled = false
            }
            else if currentIndex >= documents.count - 1 {
                nextDocumentButton.isEnabled = false
            }
            documentIndexLabel.text = "\(currentIndex + 1) / \(documents.count)"
        }
    }
    
    @IBAction func previousDocumentButtonTapped(_ sender: UIButton) {
        if currentIndex > 0 {
            currentIndex -= 1
            currentImageIndex = 0
            updateDisplayedDocument()
        }
    }
    @IBAction func nextDocumentButtonTapped(_ sender: UIButton) {
        if currentIndex < documents.count - 1 {
            currentIndex += 1
            currentImageIndex = 0
            updateDisplayedDocument()
        }
    }
    @IBAction func imagePageControlChanged(_ sender: UIPageControl) {
        if images.count > 1 {
            updateImageView()
        }
    }
    @IBAction func imageViewTapped(_ sender: UITapGestureRecognizer) {
    }
    @IBAction func imageViewSwipedRight(_ sender: UISwipeGestureRecognizer) {
        if images.count > 1 {
            currentImageIndex = (currentImageIndex - 1) % images.count
            if currentImageIndex < 0 {
                currentImageIndex = images.count - 1
            }
            updateImageView()
        }
    }
    @IBAction func imageViewSwipedLeft(_ sender: UISwipeGestureRecognizer) {
        if images.count > 1 {
            currentImageIndex = (currentImageIndex + 1) % images.count
            updateImageView()
        }
    }
    @IBAction func closeButtonTapped(_ sender: UIButton) {
        self.removeFromSuperview()
    }
}

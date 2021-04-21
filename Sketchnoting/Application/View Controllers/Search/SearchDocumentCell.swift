//
//  SearchDocumentCell.swift
//  Sketchnoting
//
//  Created by Aryobarzan on 02/04/2021.
//  Copyright © 2021 Aryobarzan. All rights reserved.
//

import UIKit

class SearchDocumentCell: UITableViewCell {

    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var subtitleLabel: UILabel!
    @IBOutlet weak var bodyTextView: UITextView!
    @IBOutlet weak var previewImageView: UIImageView!
    @IBOutlet weak var imagesPageControl: UIPageControl!
    @IBOutlet weak var nextButton: UIButton!
    @IBOutlet weak var previousButton: UIButton!
    @IBOutlet weak var pageLabel: UILabel!
    @IBOutlet weak var progressView: UIProgressView!
    
    var documents = [(Document, Double)]()
    var images = [UIImage]()
    
    var currentIndex = 0
    var currentImageIndex = 0
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
        previewImageView.layer.masksToBounds = true
        previewImageView.layer.cornerRadius = 50
        previewImageView.layer.borderWidth = 1
        previewImageView.layer.borderColor = UIColor.systemGray.cgColor
        previewImageView.tintColor = .gray
        previewImageView.isUserInteractionEnabled = true
    }

    func setContent(query: String, documents: [(Document, Double)]) {
        self.documents = documents
        self.documents = documents.sorted { document1, document2 in
            document1.1 > document2.1
        }
        currentIndex = 0
        currentImageIndex = 0
        updateDisplayedDocument()
        updateDocumentIndex()
        subtitleLabel.text = "For search query: '\(query)'"
    }
    
    @IBAction func previewImageViewSwipeLeft(_ sender: UISwipeGestureRecognizer) {
        if images.count > 1 {
            currentImageIndex = (currentImageIndex + 1) % images.count
            updateImageView()
        }
    }
    @IBAction func previewImageViewSwipeRight(_ sender: UISwipeGestureRecognizer) {
        if images.count > 1 {
            currentImageIndex = (currentImageIndex - 1) % images.count
            if currentImageIndex < 0 {
                currentImageIndex = images.count - 1
            }
            updateImageView()
        }
    }
    @IBAction func nextButtonTapped(_ sender: UIButton) {
        if currentIndex < documents.count - 1 {
            currentIndex += 1
            currentImageIndex = 0
            updateDisplayedDocument()
        }
    }
    @IBAction func previousButtonTapped(_ sender: UIButton) {
        if currentIndex > 0 {
            currentIndex -= 1
            currentImageIndex = 0
            updateDisplayedDocument()
        }
    }
    
    private func updateDisplayedDocument() {
        if !documents.isEmpty {
            let document = documents[currentIndex]
            titleLabel.text = document.0.title
            bodyTextView.text = document.0.getDescription()
            progressView.setProgress(Float(document.1), animated: true)
        }
        fetchDocumentImages()
        updateDocumentIndex()
    }
    
    private func fetchDocumentImages() {
        if !documents.isEmpty {
            images = [UIImage]()
            self.previewImageView.image = UIImage(systemName: "book.circle")
            let currentDocument = documents[currentIndex].0
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
            self.previewImageView.image = UIImage(systemName: "book.circle")
            if !self.images.isEmpty {
                self.previewImageView.image = self.images[self.currentImageIndex]
            }
            if self.images.count < 2 {
                self.imagesPageControl.isHidden = true
            }
            else {
                self.imagesPageControl.isHidden = false
                self.imagesPageControl.currentPage = self.currentImageIndex
            }
        }
    }
    
    private func updateDocumentIndex() {
        previousButton.isEnabled = true
        nextButton.isEnabled = true
        if documents.count < 2 {
            previousButton.isHidden = true
            nextButton.isHidden = true
            pageLabel.isHidden = true
        }
        else {
            previousButton.isHidden = false
            nextButton.isHidden = false
            pageLabel.isHidden = false
            if currentIndex == 0 {
                previousButton.isEnabled = false
            }
            else if currentIndex >= documents.count - 1 {
                nextButton.isEnabled = false
            }
        }
        pageLabel.text = "\(currentIndex + 1) / \(Int(documents.count))"
    }
    
}

//
//  DocumentDetailViewController.swift
//  Sketchnoting
//
//  Created by Aryobarzan on 29/11/2019.
//  Copyright © 2019 Aryobarzan. All rights reserved.
//

import UIKit
import SafariServices

class DocumentDetailViewController: UIViewController, DocumentVisitor {

    @IBOutlet weak var backButton: UIButton!
    @IBOutlet weak var previewImage: UIImageView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var typeLabel: UILabel!
    @IBOutlet weak var contentTextView: UITextView!
    @IBOutlet weak var backgroundBlurEffect: UIVisualEffectView!
    @IBOutlet weak var typeImageView: UIImageView!
    
    private var document: Document? {
        didSet {
            if let document = document {
                titleLabel.text = document.title
                typeLabel.text = document.documentType.rawValue
                typeLabel.textColor = document.getColor()
                typeImageView.image = document.getSymbol()
                typeImageView.tintColor = document.getColor()
                previewImage.image = UIImage(systemName: "questionmark.circle.fill")
                document.retrieveImage(type: .Standard, completion: { result in
                    switch result {
                    case .success(let value):
                        if let value = value {
                            DispatchQueue.main.async {
                                self.previewImage.image = value
                            }
                        }
                    case .failure(_):
                        logger.error("No preview image found for document \(document.title).")
                    }
                })
                document.accept(visitor: self)
            }
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(mapImageTapped(tapGestureRecognizer:)))
        previewImage.layer.masksToBounds = true
        previewImage.layer.cornerRadius = 64
        previewImage.layer.borderWidth = 1
        previewImage.layer.borderColor = UIColor.white.cgColor
        previewImage.tintColor = .white
        backgroundBlurEffect.layer.masksToBounds = true
        backgroundBlurEffect.layer.cornerRadius = 5
    }
    
    func setDocument(document: Document, isInBookshelf: Bool = true) {
        backButton.isHidden = !isInBookshelf
        self.document = document
    }
    
    internal func process(document: Document) {
        if let description = document.getDescription() {
            self.setDetailDescription(text: description)
        }
    }
    
    internal func process(document: TAGMEDocument) {
        if let description = document.getDescription() {
            self.setDetailDescription(text: description)
        }
        loadMapImage(document: document)
    }
    
    internal func process(document: WATDocument) {
        if let description = document.getDescription() {
            self.setDetailDescription(text: description)
        }
        loadMapImage(document: document)
    }
    
    internal func process(document: BioPortalDocument) {
        if let definition = document.definition {
            self.setDetailDescription(text: definition)
        }
    }
    
    internal func process(document: CHEBIDocument) {
        if let definition = document.definition {
            self.setDetailDescription(text: definition)
        }
        if let moleculeImage = document.moleculeImage {
            //bottomImageView.image = moleculeImage
        }
    }
    
    internal func process(document: ARDocument) {
        contentTextView.dataDetectorTypes = UIDataDetectorTypes.link
        self.setDetailDescription(text: document.getDescription() ?? "")
        if document.URL.contains(".reality") {
            let safariVC = SFSafariViewController(url: URL(string: document.URL)!)
            safariVC.modalPresentationStyle = .pageSheet
            present(safariVC, animated: true)
        }
    }
    
    private func loadMapImage(document: Document) {
        document.retrieveImage(type: .Map, completion: { result in
            switch result {
            case .success(let value):
                if let mapImage = value {
                    logger.info("Map image found for document \(document.title).")
                    DispatchQueue.main.async {
                        //self.bottomImageView.image = mapImage
                    }
                }
            case .failure(_): break
                // log.error("No map image found for document \(document.title).")
            }
        })
    }
    
    private func setDetailDescription(text: String) {
        contentTextView.text = text
    }
    
    
    @objc func mapImageTapped(tapGestureRecognizer: UITapGestureRecognizer)
    {
        let tappedImage = tapGestureRecognizer.view as! UIImageView
        let newImageView = UIImageView(image: tappedImage.image)
        newImageView.frame = UIScreen.main.bounds
        newImageView.backgroundColor = .black
        newImageView.contentMode = .scaleAspectFit
        newImageView.isUserInteractionEnabled = true
        let tap = UITapGestureRecognizer(target: self, action: #selector(dismissFullscreenMapImage))
        newImageView.addGestureRecognizer(tap)
        self.view.addSubview(newImageView)
        self.navigationController?.isNavigationBarHidden = true
        self.tabBarController?.tabBar.isHidden = true
    }
    @objc func dismissFullscreenMapImage(_ sender: UITapGestureRecognizer) {
        self.navigationController?.isNavigationBarHidden = true
        self.tabBarController?.tabBar.isHidden = true
        sender.view?.removeFromSuperview()
    }

    @IBAction func backClicked(_ sender: UIButton) {
        self.view.isHidden = true
    }
}

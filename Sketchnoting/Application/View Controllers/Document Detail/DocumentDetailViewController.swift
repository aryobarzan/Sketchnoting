//
//  DocumentDetailViewController.swift
//  Sketchnoting
//
//  Created by Aryobarzan on 29/11/2019.
//  Copyright © 2019 Aryobarzan. All rights reserved.
//

import UIKit
import WebKit

class DocumentDetailViewController: UIViewController, DocumentVisitor, WKUIDelegate {

    @IBOutlet weak var previewImage: UIImageView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var typeBackView: UIView!
    @IBOutlet weak var typeLabel: UILabel!
    @IBOutlet weak var contentTextView: UITextView!
    @IBOutlet weak var bottomImageView: UIImageView!
    @IBOutlet weak var backButton: UIButton!
    @IBOutlet weak var backgroundBlurEffect: UIVisualEffectView!
    
    //var webView: WKWebView?
    
    var document: Document!
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(mapImageTapped(tapGestureRecognizer:)))
        bottomImageView.isUserInteractionEnabled = true
        bottomImageView.addGestureRecognizer(tapGestureRecognizer)
        previewImage.layer.masksToBounds = true
        previewImage.layer.cornerRadius = 64
        previewImage.layer.borderWidth = 1
        previewImage.layer.borderColor = UIColor.white.cgColor
        previewImage.tintColor = .white
        typeBackView.layer.masksToBounds = true
        typeBackView.layer.cornerRadius = 15
        backgroundBlurEffect.layer.masksToBounds = true
        backgroundBlurEffect.layer.cornerRadius = 5
    }
    
    func setDocument(document: Document) {
        titleLabel.text = document.title
        typeLabel.text = "Document"
        previewImage.image = UIImage(systemName: "questionmark.circle.fill")
        bottomImageView.image = nil
        document.retrieveImage(type: .Standard, completion: { result in
            switch result {
            case .success(let value):
                if let value = value {
                    DispatchQueue.main.async {
                        self.previewImage.image = value
                    }
                }
            case .failure(_):
                log.error("No preview image found for document \(document.title).")
            }
        })
        document.accept(visitor: self)
    }
    
    func process(document: Document) {
        if let description = document.description {
            self.setDetailDescription(text: description)
        }
    }
    
    func process(document: SpotlightDocument) {
        typeBackView.backgroundColor = #colorLiteral(red: 0.1764705926, green: 0.01176470611, blue: 0.5607843399, alpha: 1)
        typeLabel.text = "Spotlight"
        if let label = document.label {
            titleLabel.text = label
        }
        if let description = document.description {
            self.setDetailDescription(text: description)
        }
        if let mapImage = document.mapImage {
            bottomImageView.image = mapImage
        }
    }
    
    func process(document: TAGMEDocument) {
        typeBackView.backgroundColor = #colorLiteral(red: 0.1764705926, green: 0.4980392158, blue: 0.7568627596, alpha: 1)
        typeLabel.text = "TAGME"
        titleLabel.text = document.title
        if let description = document.description {
            self.setDetailDescription(text: description)
        }
        if let mapImage = document.mapImage {
            bottomImageView.image = mapImage
        }
    }
    
    func process(document: WATDocument) {
        typeBackView.backgroundColor = #colorLiteral(red: 0.8549019694, green: 0.250980407, blue: 0.4784313738, alpha: 1)
        typeLabel.text = "WAT"
        titleLabel.text = document.title
        if let description = document.description {
            self.setDetailDescription(text: description)
        }
        if let mapImage = document.mapImage {
            bottomImageView.image = mapImage
        }
    }
    
    func process(document: BioPortalDocument) {
        typeBackView.backgroundColor = #colorLiteral(red: 0.3411764801, green: 0.6235294342, blue: 0.1686274558, alpha: 1)
        typeLabel.text = "BioPortal"
        if let definition = document.definition {
            self.setDetailDescription(text: definition)
        }
    }
    
    func process(document: CHEBIDocument) {
        typeBackView.backgroundColor = #colorLiteral(red: 0.9529411793, green: 0.6862745285, blue: 0.1333333403, alpha: 1)
        typeLabel.text = "CHEBI"
        if let definition = document.definition {
            self.setDetailDescription(text: definition)
        }
        if let moleculeImage = document.moleculeImage {
            bottomImageView.image = moleculeImage
        }
    }
    func process(document: ARDocument) {
        typeBackView.backgroundColor = #colorLiteral(red: 0.9254902005, green: 0.2352941185, blue: 0.1019607857, alpha: 1)
        typeLabel.text = "AR"
        contentTextView.dataDetectorTypes = UIDataDetectorTypes.link
        self.setDetailDescription(text: document.URL)
//        if let webView = webView {
//            webView.removeFromSuperview()
//        }
//        let config = WKWebViewConfiguration()
//        webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 200, height: 200), configuration: config)
//        DispatchQueue.main.async {
//            self.webView!.load(URLRequest(url: URL(string: document.URL)!))
//        }
//        webView!.uiDelegate = self
//        view.addSubview(webView!)
//        webView!.translatesAutoresizingMaskIntoConstraints = false
//        webView!.topAnchor.constraint(equalTo: contentTextView.topAnchor).isActive = true
//        webView!.bottomAnchor.constraint(equalTo: contentTextView.bottomAnchor).isActive = true
//        webView!.leadingAnchor.constraint(equalTo: contentTextView.leadingAnchor, constant: 10).isActive = true
//        webView!.trailingAnchor.constraint(equalTo: contentTextView.trailingAnchor, constant: 10).isActive = true
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

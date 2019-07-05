//
//  DocumentView.swift
//  Sketchnoting
//
//  Created by Aryobarzan on 13/03/2019.
//  Copyright © 2019 Aryobarzan. All rights reserved.
//

import UIKit

// This is the view used for displaying a single related document

class DocumentView: UIView, UIGestureRecognizerDelegate {
    let kCONTENT_XIB_NAME = "DocumentView"
    
    @IBOutlet var contentView: UIView!
    @IBOutlet var titleLabel: UILabel!
    @IBOutlet var bottomLine: UIView!
    @IBOutlet var scrollView: UIScrollView!
    var abstractLabel = UILabel()
    @IBOutlet var imageView: UIImageView!
    @IBOutlet var actionsButton: UIButton!
    @IBOutlet var textMapSegment: UISegmentedControl!
    @IBOutlet var imageViewTapGesture: UITapGestureRecognizer!
    
    var urlString: String?
    var mapImage: UIImage?
    var viewController: UIViewController?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        commonInit()
    }
    
    func commonInit() {
        Bundle.main.loadNibNamed(kCONTENT_XIB_NAME, owner: self, options: nil)
        contentView.fixInView(self)
        self.widthAnchor.constraint(equalToConstant: 400).isActive = true
        self.heightAnchor.constraint(equalToConstant: 280).isActive = true
        
        abstractLabel.numberOfLines = 50
        scrollView.addSubview(abstractLabel)
        abstractLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            abstractLabel.topAnchor.constraint(equalTo: scrollView.topAnchor),
            abstractLabel.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            abstractLabel.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            abstractLabel.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            abstractLabel.widthAnchor.constraint(equalTo: scrollView.widthAnchor)
            ])
        
        imageViewTapGesture.delegate = self
    }
    
    @IBAction func actionsButtonTapped(_ sender: UIButton) {
        guard let url = URL(string: self.urlString ?? "") else { return }
        UIApplication.shared.open(url)
    }
    
    @IBAction func textMapSegmentTapped(_ sender: UISegmentedControl) {
        if textMapSegment.selectedSegmentIndex == 0 {
            self.imageView.isHidden = true
            self.scrollView.isHidden = false
        }
        else {
            self.imageView.isHidden = false
            self.scrollView.isHidden = true
        }
    }
    @IBAction func imageViewTapped(_ sender: AnyObject) {
        let newImageView = UIImageView(image: imageView.image)
        newImageView.frame = UIScreen.main.bounds
        newImageView.backgroundColor = .black
        newImageView.contentMode = .scaleAspectFit
        newImageView.isUserInteractionEnabled = true
        let tap = UITapGestureRecognizer(target: self, action: #selector(dismissFullscreenImage))
        newImageView.addGestureRecognizer(tap)
        viewController!.view.addSubview(newImageView)
        viewController!.navigationController?.isNavigationBarHidden = true
        viewController!.tabBarController?.tabBar.isHidden = true
    }
    
    @objc func dismissFullscreenImage(_ sender: UITapGestureRecognizer) {
        viewController!.navigationController?.isNavigationBarHidden = false
        viewController!.tabBarController?.tabBar.isHidden = false
        sender.view?.removeFromSuperview()
    }
    
    func setMapImage(image: UIImage) {
        self.mapImage = image
        self.imageView.image = mapImage
        self.textMapSegment.isHidden = false
    }
}

//
//  NoteLayersViewCell.swift
//  Sketchnoting
//
//  Created by Aryobarzan on 19/08/2020.
//  Copyright © 2020 Aryobarzan. All rights reserved.
//

import UIKit

import fluid_slider

class NoteLayersViewCell: UITableViewCell {

    @IBOutlet weak var typeImageView: UIImageView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var captionLabel: UILabel!
    @IBOutlet weak var draggableImageView: UIImageView!
    @IBOutlet weak var bottomControlImage: UIImageView!
    @IBOutlet weak var bottomContainerView: UIView!
    
    var item: NoteLayerItem!
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }
    
    func set(item: NoteLayerItem) {
        self.item = item
        
        switch item.type {
        case .Canvas:
            typeImageView.image = UIImage(systemName: "pencil.and.outline")
            titleLabel.text = "Canvas"
            captionLabel.text = "Contains your Pencil strokes."
            draggableImageView.isHidden = true
            bottomControlImage.isHidden = true
            bottomContainerView.isHidden = true
        case .Layer:
            draggableImageView.isHidden = false
            bottomControlImage.isHidden = true
            bottomContainerView.isHidden = true
            if let layer = item.layer {
                switch layer.type {
                case .Image:
                    typeImageView.image = UIImage(systemName: "photo")
                    titleLabel.text = "Photo"
                    captionLabel.text = "Imported photo."
                case .TypedText:
                    typeImageView.image = UIImage(systemName: "textbox")
                    titleLabel.text = "Text Box"
                    captionLabel.text = "Imported text."
                }
            }
        case .PDF:
            typeImageView.image = UIImage(systemName: "doc.richtext")
            titleLabel.text = "PDF"
            captionLabel.text = "Imported PDF."
            draggableImageView.isHidden = true
            bottomControlImage.isHidden = false
            bottomContainerView.isHidden = false
            
            bottomContainerView.subviews.forEach { view in
                view.removeFromSuperview()
            }
            
            let slider = Slider(frame: bottomContainerView.frame)
            slider.attributedTextForFraction = { fraction in
                let formatter = NumberFormatter()
                formatter.maximumIntegerDigits = 3
                formatter.maximumFractionDigits = 0
                let string = formatter.string(from: (fraction * 150) as NSNumber) ?? ""
                return NSAttributedString(string: string)
            }
            slider.setMinimumLabelAttributedText(NSAttributedString(string: "1"))
            slider.setMaximumLabelAttributedText(NSAttributedString(string: "150"))
            slider.fraction = 0.5
            slider.shadowOffset = CGSize(width: 0, height: 10)
            slider.shadowBlur = 5
            slider.shadowColor = UIColor(white: 0, alpha: 0.1)
            slider.contentViewColor = UIColor(red: 78/255.0, green: 77/255.0, blue: 224/255.0, alpha: 1)
            slider.valueViewColor = .white
            bottomContainerView.addSubview(slider)
            slider.addTarget(self, action: #selector(pdfZoomSliderValueChanged), for: .valueChanged)
        }
    }
    
    @objc func pdfZoomSliderValueChanged(_ sender: Slider) {
        log.info(sender.fraction)
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }

}

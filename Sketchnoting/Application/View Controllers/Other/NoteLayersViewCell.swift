//
//  NoteLayersViewCell.swift
//  Sketchnoting
//
//  Created by Aryobarzan on 19/08/2020.
//  Copyright © 2020 Aryobarzan. All rights reserved.
//

import UIKit

class NoteLayersViewCell: UITableViewCell {

    @IBOutlet weak var typeImageView: UIImageView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var captionLabel: UILabel!
    @IBOutlet weak var draggableImageView: UIImageView!
    @IBOutlet weak var bottomControlImage: UIImageView!
    @IBOutlet weak var zoomLabel: UILabel!
    @IBOutlet weak var zoomStepper: UIStepper!
    
    var item: NoteLayerItem!
    var delegate: NoteLayersViewCellDelegate?
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
            zoomLabel.isHidden = true
            zoomStepper.isHidden = true
        case .Layer:
            draggableImageView.isHidden = false
            bottomControlImage.isHidden = true
            zoomLabel.isHidden = true
            zoomStepper.isHidden = true
            if let layer = item.layer {
                switch layer.type {
                case .Image:
                    typeImageView.image = UIImage(systemName: "photo")
                    if let noteImage = layer as? NoteImage {
                        typeImageView.image = noteImage.image
                    }
                    titleLabel.text = "Photo"
                    captionLabel.text = "Imported photo."
                case .TypedText:
                    typeImageView.image = UIImage(systemName: "textbox")
                    titleLabel.text = "Text Box"
                    captionLabel.text = "Imported text."
                    if let noteTypedText = layer as? NoteTypedText {
                        captionLabel.text = noteTypedText.text
                    }
                }
            }
        case .PDF:
            typeImageView.image = UIImage(systemName: "doc.richtext")
            titleLabel.text = "PDF"
            captionLabel.text = "Imported PDF."
            draggableImageView.isHidden = true
            bottomControlImage.isHidden = false
            zoomLabel.isHidden = false
            zoomStepper.isHidden = false
            zoomLabel.text = "\(Int(floor(item.zoom! * 100)))%"
            zoomStepper.value = Double((item.zoom! * 100))
        }
    }

    @IBAction func zoomStepperChanged(_ sender: UIStepper) {
        delegate?.zoomValueChanged(value: sender.value/100)
        zoomLabel.text = "\(Int(floor(sender.value)))%"
    }
    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }

}


protocol NoteLayersViewCellDelegate {
    func zoomValueChanged(value: Double)
}

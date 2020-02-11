//
//  SearchFilterCollectionViewCell.swift
//  Sketchnoting
//
//  Created by Aryobarzan on 11/02/2020.
//  Copyright © 2020 Aryobarzan. All rights reserved.
//

import UIKit

class SearchFilterCollectionViewCell: UICollectionViewCell {
    
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var label: UILabel!
    public var filter: SearchFilter?
    
    override func awakeFromNib() {
        super.awakeFromNib()
    }
    required init?(coder aDecoder: NSCoder) {
           super.init(coder: aDecoder)
    }
    
    public func setFilter(filter: SearchFilter) {
        self.filter = filter
        label.text = filter.term
        switch filter.type {
        case .All:
            imageView.image = UIImage(systemName: "magnifyingglass.circle.fill")
        case .Text:
            imageView.image = UIImage(systemName: "text.alignleft")
        case .Drawing:
            imageView.image = UIImage(systemName: "scribble")
        case .Document:
            imageView.image = UIImage(systemName: "doc")
        }
    }
}

//
//  SearchInformationCell.swift
//  Sketchnoting
//
//  Created by Aryobarzan on 02/04/2021.
//  Copyright © 2021 Aryobarzan. All rights reserved.
//

import UIKit

class SearchInformationCell: UITableViewCell {

    @IBOutlet weak var leftImageView: UIImageView!
    @IBOutlet weak var informationLabel: UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
        // Configure the view for the selected state
    }
    
    func setContent(message: String, type: SearchTableInformationItemType = .Basic) {
        informationLabel.text = message
        switch type {
        case .Basic:
            leftImageView.image = UIImage(systemName: "info.circle.fill")
            break
        case .Subqueries:
            leftImageView.image = UIImage(systemName: "magnifyingglass.circle.fill")
            break
        case .QuestionAnswer:
            leftImageView.image = UIImage(systemName: "questionmark.circle.fill")
            break
        }
        
    }
}

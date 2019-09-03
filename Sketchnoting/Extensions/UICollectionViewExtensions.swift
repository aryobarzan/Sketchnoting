//
//  UICollectionViewExtensions.swift
//  Sketchnoting
//
//  Created by Aryobarzan on 03/09/2019.
//  Copyright © 2019 Aryobarzan. All rights reserved.
//

import UIKit

extension UICollectionView {
    func scrollToBottom(animated: Bool) {
        if self.contentSize.height < self.bounds.size.height { return }
        let bottomOffset = CGPoint(x: 0, y: self.contentSize.height - self.bounds.size.height)
        self.setContentOffset(bottomOffset, animated: animated)
    }
}

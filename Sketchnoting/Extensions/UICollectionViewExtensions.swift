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
    func refreshLayout() {
        let oldLayout = collectionViewLayout as! UICollectionViewFlowLayout
        let newLayout = UICollectionViewFlowLayout()
        newLayout.estimatedItemSize = oldLayout.estimatedItemSize
        newLayout.footerReferenceSize = oldLayout.footerReferenceSize
        newLayout.headerReferenceSize = oldLayout.headerReferenceSize
        newLayout.itemSize = oldLayout.itemSize
        newLayout.minimumInteritemSpacing = oldLayout.minimumInteritemSpacing
        newLayout.minimumLineSpacing = oldLayout.minimumLineSpacing
        newLayout.scrollDirection = oldLayout.scrollDirection
        newLayout.sectionFootersPinToVisibleBounds = oldLayout.sectionFootersPinToVisibleBounds
        newLayout.sectionHeadersPinToVisibleBounds = oldLayout.sectionHeadersPinToVisibleBounds
        newLayout.sectionInset = oldLayout.sectionInset
        newLayout.sectionInsetReference = oldLayout.sectionInsetReference
        collectionViewLayout = newLayout
    }
}

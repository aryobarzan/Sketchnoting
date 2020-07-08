//
//  FolderButton.swift
//  Sketchnoting
//
//  Created by Aryobarzan on 17/02/2020.
//  Copyright © 2020 Aryobarzan. All rights reserved.
//

import UIKit

class FolderButton: UIButton {
    var delegate: FolderButtonDelegate?
    var directoryURL: URL!
    
    func set(directoryURL: URL) {
        self.directoryURL = directoryURL
        self.addTarget(self, action: #selector(onTap), for: .touchUpInside)
        self.setTitleColor(.link, for: .normal)
        self.setTitle(" \(directoryURL.deletingPathExtension().lastPathComponent)", for: .normal)
        self.setImage(UIImage(systemName: "arrow.right"), for: .normal)
        if NeoLibrary.isHomeDirectory(url: directoryURL) {
            self.setImage(UIImage(systemName: "house"), for: .normal)
        }
    }

    @objc func onTap(sender: UIButton!) {
        self.delegate?.onTap(directoryURL: directoryURL)
    }
}

protocol FolderButtonDelegate {
    func onTap(directoryURL: URL)
}

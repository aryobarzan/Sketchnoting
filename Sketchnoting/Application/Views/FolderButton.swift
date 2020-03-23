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
    var folder: Folder?
    
    func setFolder(folder: Folder?) {
        self.folder = folder
        self.addTarget(self, action: #selector(onTap), for: .touchUpInside)
        self.setTitleColor(.link, for: .normal)
        if let folder = folder {
            self.setTitle(" " + folder.getName(), for: .normal)
            self.setImage(UIImage(systemName: "arrow.turn.down.right"), for: .normal)
        }
        else {
            self.setTitle(" Home", for: .normal)
            self.setImage(UIImage(systemName: "house"), for: .normal)
        }
    }

    @objc func onTap(sender: UIButton!) {
        self.delegate?.onTap(folder: folder)
    }
}

protocol FolderButtonDelegate {
    func onTap(folder: Folder?)
}

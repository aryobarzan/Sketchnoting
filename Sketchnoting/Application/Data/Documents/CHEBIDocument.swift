//
//  CHEBIDocument.swift
//  Sketchnoting
//
//  Created by Aryobarzan on 16/07/2019.
//  Copyright © 2019 Aryobarzan. All rights reserved.
//

import UIKit

class CHEBIDocument: BioPortalDocument {
    
    var moleculeImage: UIImage?
    
    init?(title: String, description: String?, URL: String, type: DocumentType, prefLabel: String, definition: String, moleculeImage: UIImage?) {
        self.moleculeImage = moleculeImage
        super.init(title: title, description: description, URL: URL, type: type, prefLabel: prefLabel, definition: definition)
    }
    
    override func encode(to encoder: Encoder) throws {
        try super.encode(to: encoder)
    }
    
    required init(from decoder: Decoder) throws {
        try super.init(from: decoder)
        
        loadMoleculeImage()
    }
    
    //MARK: Visitable
    override func accept(visitor: DocumentVisitor) {
        visitor.process(document: self)
    }
    
    private func loadMoleculeImage() {
        self.retrieveImage(type: .Molecule, completion: { result in
            switch result {
            case .success(let value):
                if value != nil {
                    log.info("Molecule image found for document \(self.title).")
                    DispatchQueue.main.async {
                        self.moleculeImage = value!
                    }
                }
            case .failure(let error):
                log.error("No molecule image found for document \(self.title).")
                print(error)
            }
        })
    }
    
    override func reload() {
        loadMoleculeImage()
        delegate?.documentHasChanged(document: self)
    }
}

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
    
    override func getColor() -> UIColor {
        return #colorLiteral(red: 0.9529411793, green: 0.6862745285, blue: 0.1333333403, alpha: 1)
    }
    
    override func getSymbol() -> UIImage? {
        return UIImage(systemName: "c.circle")
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
                    logger.info("Molecule image found for document \(self.title).")
                    DispatchQueue.main.async {
                        self.moleculeImage = value!
                    }
                }
            case .failure(let error):
                logger.error("No molecule image found for document \(self.title).")
                print(error)
            }
        })
    }
    
    override func reload() {
        loadMoleculeImage()
        delegate?.documentHasChanged(document: self)
    }
}

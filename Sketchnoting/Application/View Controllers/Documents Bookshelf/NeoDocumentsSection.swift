//
//  NeoDocumentsSection.swift
//  Sketchnoting
//
//  Created by Aryobarzan on 20/07/2020.
//  Copyright © 2020 Aryobarzan. All rights reserved.
//

import UIKit

class Section: Hashable {
    var id = UUID()
    var documentType: DocumentType
    var documents: [Document]
    
    init(documentType: DocumentType, documents: [Document]) {
        self.documentType = documentType
        self.documents = documents
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: Section, rhs: Section) -> Bool {
        lhs.id == rhs.id
    }
}

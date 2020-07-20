//
//  NeoDocumentsSection.swift
//  Sketchnoting
//
//  Created by Aryobarzan on 20/07/2020.
//  Copyright © 2020 Aryobarzan. All rights reserved.
//

import UIKit

// 1
class Section: Hashable {
  var id = UUID()
  // 2
    var documentType: DocumentType
  // 3
  var documents: [Document]
  
    init(documentType: DocumentType, documents: [Document]) {
    self.documentType = documentType
    self.documents = documents
  }
  // 4
  func hash(into hasher: inout Hasher) {
    hasher.combine(id)
  }
  
  static func == (lhs: Section, rhs: Section) -> Bool {
    lhs.id == rhs.id
  }
}

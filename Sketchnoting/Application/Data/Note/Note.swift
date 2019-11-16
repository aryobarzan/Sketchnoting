//
//  Note.swift
//  Sketchnoting
//
//  Created by Aryobarzan on 25/02/2019.
//  Copyright © 2019 Aryobarzan. All rights reserved.
//

import UIKit
// In its current state this abstraction is not needed.
// Initially, the application was going to have textual notes and sketchnotes (i.e. only handwriting/drawing, no typing), hence the abstraction of having a top level Note interface/protocol.
// For future work, should the application also support typed notes, some common functions will be moved from the Sketchnote class to this protocol, as there would be 2 classes implementing this protocol (Sketchnote and TextNote)
protocol Note: Codable {
}

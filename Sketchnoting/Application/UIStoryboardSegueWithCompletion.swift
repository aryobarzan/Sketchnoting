//
//  UIStoryboardSegueWithCompletion.swift
//  Sketchnoting
//
//  Created by Aryobarzan on 24/11/2019.
//  Copyright © 2019 Aryobarzan. All rights reserved.
//
import UIKit

class UIStoryboardSegueWithCompletion: UIStoryboardSegue {
    var completion: (() -> Void)?

    override func perform() {
        super.perform()
        if let completion = completion {
            completion()
        }
    }
}

//
//  DrawingSearchViewController.swift
//  Sketchnoting
//
//  Created by Aryobarzan on 11/02/2020.
//  Copyright © 2020 Aryobarzan. All rights reserved.
//

import UIKit

import PencilKit

class DrawingSearchViewController: UIViewController, PKCanvasViewDelegate {

    @IBOutlet weak var canvasView: PKCanvasView!
    @IBOutlet weak var searchButton: UIButton!
    var searchLabel: String?
    var delegate: DrawingSearchDelegate?
    override func viewDidLoad() {
        super.viewDidLoad()
        
        canvasView.tool = PKInkingTool(.pen, color: .black, width: 4)
        canvasView.drawing = PKDrawing()
        canvasView.delegate = self
        canvasView.overrideUserInterfaceStyle = .dark
        canvasView.layer.masksToBounds = true
        canvasView.layer.cornerRadius = 5
        
        SKRecognizer.initializeRecognizers()
    }

    @IBAction func searchTapped(_ sender: UIButton) {
        if searchLabel != nil && !searchLabel!.isEmpty {
            delegate?.drawingSearchRecognized(label: searchLabel!)
            self.dismiss(animated: true, completion: nil)
        }
    }
    @IBAction func clearDrawingTapped(_ sender: UIButton) {
        canvasView.drawing = PKDrawing()
        self.searchButton.setTitle(" Not recognized", for: .normal)
        self.searchButton.isEnabled = false
    }
    func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
        if canvasView.drawing.strokes.isEmpty {
            self.searchButton.setTitle(" Not recognized", for: .normal)
            self.searchButton.isEnabled = false
        } else {
            SKRecognizer.recognize(canvasView: canvasView, recognitionType: .Drawing) { success, result in
                if success {
                    self.searchButton.setTitle(" " + result!, for: .normal)
                    self.searchButton.isEnabled = true
                    self.searchLabel = result!
                    logger.info("Best prediction: \(result!)")
                }
                else {
                    self.searchButton.setTitle(" Not recognized", for: .normal)
                    self.searchButton.isEnabled = false
                }
            }
        }
    }
}

protocol DrawingSearchDelegate {
    func drawingSearchRecognized(label: String)
}

//
//  DrawingSearchViewController.swift
//  Sketchnoting
//
//  Created by Aryobarzan on 11/02/2020.
//  Copyright © 2020 Aryobarzan. All rights reserved.
//

import UIKit

import PencilKit
import GPUImage

class DrawingSearchViewController: UIViewController, PKCanvasViewDelegate {

    @IBOutlet weak var canvasView: PKCanvasView!
    @IBOutlet weak var searchButton: UIButton!
    var searchLabel: String?
    var delegate: DrawingSearchDelegate?
    var drawingRecognition = DrawingRecognition()
    override func viewDidLoad() {
        super.viewDidLoad()
        
        canvasView.tool = PKInkingTool(.pen, color: .black, width: 75)
        canvasView.drawing = PKDrawing()
        canvasView.delegate = self
        canvasView.overrideUserInterfaceStyle = .dark
        canvasView.layer.masksToBounds = true
        canvasView.layer.cornerRadius = 5
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
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            let image = canvasView.asImage()
            
            if let recognition = self.drawingRecognition.recognize(image: image) {
                self.searchButton.setTitle(" " + recognition, for: .normal)
                self.searchButton.isEnabled = true
                self.searchLabel = recognition
                log.info("Best prediction: \(recognition)")
            }
            else {
                self.searchButton.setTitle(" Not recognized", for: .normal)
                self.searchButton.isEnabled = false
            }
        }
    }
}

protocol DrawingSearchDelegate {
    func drawingSearchRecognized(label: String)
}

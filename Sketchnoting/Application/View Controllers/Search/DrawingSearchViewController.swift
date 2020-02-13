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
        
        canvasView.tool = PKInkingTool(.pen, color: .black, width: 75)
        canvasView.drawing = PKDrawing()
        canvasView.delegate = self
        canvasView.overrideUserInterfaceStyle = .dark
        canvasView.layer.masksToBounds = true
        canvasView.layer.cornerRadius = 5
        
        //Drawing Recognition - This loads the labels for the drawing recognition's CoreML model.
        if let path = Bundle.main.path(forResource: "labels", ofType: "txt") {
            do {
                let data = try String(contentsOfFile: path, encoding: .utf8)
                let labelNames = data.components(separatedBy: .newlines).filter { $0.count > 0 }
                self.labelNames.append(contentsOf: labelNames)
            } catch {
                log.error("Failed to load labels for drawing recognition model: \(error)")
            }
        }
    }

    @IBAction func searchTapped(_ sender: UIButton) {
        if searchLabel != nil && !searchLabel!.isEmpty {
            delegate?.drawingSearchRecognized(label: searchLabel!)
            self.dismiss(animated: true, completion: nil)
        }
    }
    @IBAction func clearDrawingTapped(_ sender: UIButton) {
        canvasView.drawing = PKDrawing()
    }
    
    func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            let image = canvasView.asImage()
            let resized = image.resize(newSize: CGSize(width: 28, height: 28))
            
            guard let pixelBuffer = resized.grayScalePixelBuffer() else {
                log.error("Failed to create pixel buffer.")
                return
            }
            do {
                self.currentPrediction = try self.drawnImageClassifier.prediction(image: pixelBuffer)
            }
            catch {
                log.error("Prediction failed: \(error)")
            }
        }
    }
    
    // Drawing recognition
    private var labelNames: [String] = []
    private let drawnImageClassifier = DrawnImageClassifier()
    private var currentPrediction: DrawnImageClassifierOutput? {
        didSet {
            if let currentPrediction = currentPrediction {
                let sorted = currentPrediction.category_softmax_scores.sorted { $0.value > $1.value }
                let top5 = sorted.prefix(5)
                print(top5.map { $0.key + "(" + String($0.value) + ")"}.joined(separator: ", "))
                var found = false
                for (label, score) in top5 {
                    if score > 0.5 {
                        searchButton.setTitle(" " + label, for: .normal)
                        searchButton.isEnabled = true
                        searchLabel = label
                        found = true
                        break
                    }
                }
                if !found {
                    searchButton.setTitle(" Not recognized", for: .normal)
                    searchButton.isEnabled = false
                }
            }
            else {
                log.info("Waiting for drawing...")
            }
        }
    }
}

protocol DrawingSearchDelegate {
    func drawingSearchRecognized(label: String)
}

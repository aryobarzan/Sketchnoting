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
        self.bestPrediction = ""
        self.bestPredictionScore = 0.0
        self.searchButton.setTitle(" Not recognized", for: .normal)
        self.searchButton.isEnabled = false
    }
    
    var bestPrediction = ""
    var bestPredictionScore = 0.0
    @IBOutlet weak var debugImageView: UIImageView!
    func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            let image = canvasView.asImage()
            
            var filteredImage = self.dilateLow(image: image)
            self.debugImageView.image = filteredImage
            self.predict(image: filteredImage)
            filteredImage = self.dilateMedium(image: image)
            self.predict(image: filteredImage)
            filteredImage = self.dilateHigh(image: image)
            self.predict(image: filteredImage)

            if self.bestPredictionScore >= 0.3 && !self.bestPrediction.isEmpty {
                self.searchButton.setTitle(" " + self.bestPrediction, for: .normal)
                self.searchButton.isEnabled = true
                self.searchLabel = self.bestPrediction
                log.info("Best prediction: \(self.bestPrediction) with a score of \(self.bestPredictionScore)")
            }
            else {
                self.searchButton.setTitle(" Not recognized", for: .normal)
                self.searchButton.isEnabled = false
            }
            self.bestPrediction = ""
            self.bestPredictionScore = 0.0
        }
    }
    
    private func dilateLow(image: UIImage) -> UIImage {
        return image.filterWithPipeline{input, output in
            input --> Dilation() --> Dilation() --> output
        }
    }
    private func dilateMedium(image: UIImage) -> UIImage {
        return image.filterWithPipeline{input, output in
            input --> Dilation() --> Dilation() --> Dilation() --> Dilation() --> output
        }
    }
    private func dilateHigh(image: UIImage) -> UIImage {
        return image.filterWithPipeline{input, output in
            input --> Dilation() --> Dilation() --> Dilation() --> Dilation() --> Dilation() --> Dilation() --> output
        }
    }
    
    private func predict(image: UIImage) {
        let resized = image.resize(newSize: CGSize(width: 28, height: 28))
            
        guard let pixelBuffer = resized.grayScalePixelBuffer() else {
            log.error("Failed to create pixel buffer.")
            return
        }
        if let prediction = try? self.drawnImageClassifier.prediction(image: pixelBuffer) {
            let sorted = prediction.category_softmax_scores.sorted { $0.value > $1.value }
            let top5 = sorted.prefix(5)
            log.info(top5.map { $0.key + "(" + String($0.value) + ")"}.joined(separator: ", "))
            for (label, score) in top5 {
                if score > bestPredictionScore {
                    bestPrediction = label
                    bestPredictionScore = score
                    self.debugImageView.image = image
                }
            }
        }
    }
    
    // Drawing recognition
    private var labelNames: [String] = []
    private let drawnImageClassifier = DrawnImageClassifier()
    
}

protocol DrawingSearchDelegate {
    func drawingSearchRecognized(label: String)
}

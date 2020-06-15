//
//  DrawingRecognition.swift
//  Sketchnoting
//
//  Created by Aryobarzan on 26/03/2020.
//  Copyright © 2020 Aryobarzan. All rights reserved.
//

import UIKit
import GPUImage

class DrawingRecognition {
    private var labelNames: [String] = []
    private let drawnImageClassifier = DrawnImageClassifier()
    init() {
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
    
    private var bestPrediction = ""
    private var bestPredictionScore = 0.0
    func recognize(image: UIImage) -> (String, Double)? {
        self.bestPrediction = ""
        self.bestPredictionScore = 0.0
            self.predict(image: image)
            for i in 1..<5 {
                var filteredImage = self.dilate(image: image, radius: i, level: .Low)
                self.predict(image: filteredImage)
                filteredImage = self.dilate(image: image, radius: i, level: .Medium)
                self.predict(image: filteredImage)
                filteredImage = self.dilate(image: image, radius: i, level: .High)
                self.predict(image: filteredImage)
            }

            if self.bestPredictionScore >= 0.3 && !self.bestPrediction.isEmpty {
                log.info("Best prediction: \(self.bestPrediction) with a score of \(self.bestPredictionScore)")
                return (self.bestPrediction, self.bestPredictionScore)
            }
            else {
                log.error("Drawing not recognized.")
                return nil
            }
    }
    enum DilationLevel {
        case Low
        case Medium
        case High
    }
    private func dilate(image: UIImage, radius: Int, level: DilationLevel) -> UIImage {
        let dilation = Dilation()
        dilation.radius = UInt(radius)
        switch level {
        case .Low:
            return image.filterWithPipeline{input, output in
                input --> dilation --> Dilation() --> output
            }
        case .Medium:
            return image.filterWithPipeline{input, output in
                input --> dilation --> Dilation() --> Dilation() --> Dilation() --> output
            }
        case .High:
            return image.filterWithPipeline{input, output in
                input --> dilation --> Dilation() --> Dilation() --> Dilation() --> Dilation() --> Dilation() --> output
            }
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
                }
            }
        }
    }
}

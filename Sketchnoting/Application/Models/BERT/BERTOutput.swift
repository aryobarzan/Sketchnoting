/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Provides helper types for the BERT model's outputs.
*/

import CoreML

extension Array where Element: Comparable {
    /// Provides the indices of the largest elements.
    ///
    /// - parameters:
    ///     - count: The number of indicies to return, at most.
    /// - returns: An array of integers.
    func indicesOfLargest(_ count: Int = 10) -> [Int] {
        let count = Swift.min(count, self.count)
        let sortedSelf = enumerated().sorted { (arg0, arg1) in arg0.element > arg1.element }
        let topElements = sortedSelf[0..<count]
        let topIndices = topElements.map { (tuple) in tuple.offset }
        return topIndices
    }
}

extension MLMultiArray {
    /// Creates a copy of the multi-array's contents into a Doubles array.
    ///
    /// - returns: An array of Doubles.
    func doubleArray() -> [Double] {
        // Bind the underlying `dataPointer` memory to make a native swift `Array<Double>`
        let unsafeMutablePointer = dataPointer.bindMemory(to: Double.self, capacity: count)
        let unsafeBufferPointer = UnsafeBufferPointer(start: unsafeMutablePointer, count: count)
        return [Double](unsafeBufferPointer)
    }
}
import Accelerate
extension BERT {
    //MARK: Vector Sum
    private func sum(x: [Double]) -> Double {
      return cblas_dasum(Int32(x.count), x, 1)
    }

    //MARK: Subtraction
    private func sub(x: [Double], y: [Double]) -> [Double] {
      var result = [Double](x)
      
      vDSP_vsubD(y, 1, x, 1, &result, 1, vDSP_Length(x.count))
      return result
    }

    private func sub(x: [Double], c: Double) -> [Double] {
      var result = (1...x.count).map{_ in c}
        
      catlas_daxpby(Int32(x.count), 1.0, x, 1, -1.0, &result, 1)
      
      return result
    }

    //MARK: Division
    private func div(x: [Double], y: [Double]) -> [Double] {
        var results = [Double](repeating: 0.0, count: x.count)
      
      vvdiv(&results, x, y, [Int32(x.count)])
        
      return results
    }

    private func div(x: [Double], c: Double) -> [Double] {
        let divisor = [Double](repeating: c, count: x.count)
        var result = [Double](repeating: 0.0, count: x.count)
      
      vvdiv(&result, x, divisor, [Int32(x.count)])
        
      return result
    }

    //MARK: Special elementwise functions
    private func exp(x: [Double]) -> [Double] {
        var results = [Double](repeating: 0.0, count: x.count)
      vvexp(&results, x, [Int32(x.count)])

      return results
    }
    //MARK: Softmax function
    private func softmax(z: [Double]) -> [Double] {
        let x = exp(x: sub(x: z, c: z.max()!))
        return div(x: x, c: sum(x: x))
    }

    /// Finds the indices of the best start logit and end logit given a prediction output and a range.
    ///
    /// - parameters:
    ///     - prediction: A feature provider that supplies the output MLMultiArrays from a BERT model.
    ///     - range: A range of the output tokens to search.
    /// - returns: Description.
    /// - Tag: BestLogitIndices
    func bestLogitsIndices(from prediction: BERTQAFP16Output, in range: Range<Int>) -> (start: Int, end: Int, confidence: Double)? {
        // Convert the logits MLMultiArrays to [Double].
        let startLogits = prediction.startLogits.doubleArray()
        let endLogits = prediction.endLogits.doubleArray()
        
        // Isolate the logits for the document.
        let startLogitsOfDoc = [Double](startLogits[range])
        let endLogitsOfDoc = [Double](endLogits[range])
        
        // Only keep the top 20 (out of the possible ~380) indices for faster searching.
        let softmaxedStartLogits = softmax(z: startLogitsOfDoc)
        let softmaxedEndLogits = softmax(z: endLogitsOfDoc)
        let topStartIndices = startLogitsOfDoc.indicesOfLargest(20)
        let topEndIndices = endLogitsOfDoc.indicesOfLargest(20)
        let averageProbability = (softmaxedStartLogits[topStartIndices[0]] + softmaxedEndLogits[topEndIndices[0]])/2
        if averageProbability < 0.5 {
            return nil
        }
        // Search for the highest valued logit pairing.
        let bestPair = findBestLogitPair(startLogits: startLogitsOfDoc,
                                         bestStartIndices: topStartIndices,
                                         endLogits: endLogitsOfDoc,
                                         bestEndIndices: topEndIndices)
        if let bestPair = bestPair {
            guard bestPair.start >= 0 && bestPair.end >= 0 else {
                return nil
            }
            var confidence = (softmaxedStartLogits[bestPair.start] + softmaxedEndLogits[bestPair.end])/2
            confidence = round(confidence * 100)/100 // Round up to 2 decimals
            return (bestPair.start, bestPair.end, confidence)
        }
        return nil
    }
    
    /// Searches the given indices for the highest valued start and end logits.
    ///
    /// - parameters:
    ///     - startLogits: An array of all the start logits.
    ///     - bestStartIndices: An array of the best start logit indices.
    ///     - endLogits: An array of all the end logits.
    ///     - bestEndIndices: An array of the best end logit indices.
    /// - returns: A tuple of the best start index and best end index.
    func findBestLogitPair(startLogits: [Double],
                           bestStartIndices: [Int],
                           endLogits: [Double],
                           bestEndIndices: [Int]) -> (start: Int, end: Int)? {
        
        let logitsCount = Int(startLogits.count)
        var bestSum = -Double.infinity
        var bestStart = -1
        var bestEnd = -1
                
        for start in 0..<logitsCount where bestStartIndices.contains(start) {
            for end in start..<logitsCount where bestEndIndices.contains(end) {
                let logitSum = startLogits[start] + endLogits[end]
                
                if logitSum > bestSum {
                    bestSum = logitSum
                    bestStart = start
                    bestEnd = end
                }
            }
        }
        if bestSum > 0 {
            return (bestStart, bestEnd)
        }
        else {
            return nil
        }
    }
}


//
//  BertForQuestionAnswering.swift
//  CoreMLBert
//
//  Created by Julien Chaumond on 27/06/2019.
//  Copyright © 2019 Hugging Face. All rights reserved.
//
import Foundation
import CoreML
import Accelerate

class DISTILBERT {

    var model: distilbert_squad_384_FP16 {
        do {
            return try distilbert_squad_384_FP16(configuration: .init())
        } catch {
            fatalError("Couldn't load DISTILBERT model due to: \(error.localizedDescription)")
        }
    }
    
    private let tokenizer = DISTILBERTTokenizer()
    public let seqLen = 384
    
    /// Main prediction loop:
    /// - featurization
    /// - model inference
    /// - argmax and re-tokenization
    func predict2(question: String, context: String) -> (answer: String, confidence: Double)? {
        let input = featurizeTokensDistilled(question: question, context: context)
        
        let (output, _) = DISTILBERTUtils.time {
            return try! model.prediction(input: input)
        }
        // Convert the logits MLMultiArrays to [Float].
        let startLogits = output.start_scores.floatArray()
        let endLogits = output.end_scores.floatArray()
        
        // Only keep the top 20 (out of the possible 382) indices for faster searching.
        let softmaxedStartLogits = softmax(z: startLogits)
        let softmaxedEndLogits = softmax(z: endLogits)
        let start = DISTILBERTMath.argmax32(output.start_scores).0
        let end = DISTILBERTMath.argmax32(output.end_scores).0
        if start < end && start >= 0 {
            var confidence = Double(max(softmaxedStartLogits[start], softmaxedEndLogits[end])) //(softmaxedStartLogits[start] + softmaxedEndLogits[end])/2
            if confidence < 0.5 {
                return nil
            }
            logger.info(softmaxedStartLogits[start])
            logger.info(softmaxedEndLogits[end])
            confidence = round(confidence * 100)/100 // Round up to 2 decimals
            let tokenIds = Array(MLMultiArray.toIntArray(input.input_ids)[start...end])
            let tokens = tokenizer.unTokenize(tokens: tokenIds)
            let answer = tokenizer.convertWordpieceToBasicTokenList(tokens)
            return (answer, confidence)
        }
        return nil
    }
    func predict(question: String, context: String) -> (answer: String, confidence: Double)? {
        let input = featurizeTokensDistilled(question: question, context: context)
        
        let (output, _) = DISTILBERTUtils.time {
            return try! model.prediction(input: input)
        }
        // Convert the logits MLMultiArrays to [Float].
        let startLogits = output.start_scores.floatArray()
        let endLogits = output.end_scores.floatArray()
        
        // Only keep the top 20 (out of the possible ~380) indices for faster searching.
        let softmaxedStartLogits = softmax(z: startLogits)
        let softmaxedEndLogits = softmax(z: endLogits)
        let topStartIndices = startLogits.indicesOfLargest(10)
        let topEndIndices = endLogits.indicesOfLargest(10)
        var confidence = max(softmaxedStartLogits[topStartIndices[0]], softmaxedEndLogits[topEndIndices[0]])
        confidence = round(confidence * 100)/100
        if confidence < 0.5 {
            return nil
        }
        // Search for the highest valued logit pairing.
        let bestPair = findBestLogitPair(startLogits: startLogits,
                                         bestStartIndices: topStartIndices,
                                         endLogits: endLogits,
                                         bestEndIndices: topEndIndices)
        if let bestPair = bestPair {
            guard bestPair.start < bestPair.end && bestPair.start >= 0 else {
                return nil
            }
            var confidence = Double(max(softmaxedStartLogits[bestPair.start], softmaxedEndLogits[bestPair.end]))
            confidence = round(confidence * 100)/100 // Round up to 2 decimals
            let tokenIds = Array(MLMultiArray.toIntArray(input.input_ids)[bestPair.start...bestPair.end])
            let tokens = tokenizer.unTokenize(tokens: tokenIds)
            let answer = tokenizer.convertWordpieceToBasicTokenList(tokens)
            return (answer, confidence)
        }
        return nil
    }
    
    private func findBestLogitPair(startLogits: [Float],
                           bestStartIndices: [Int],
                           endLogits: [Float],
                           bestEndIndices: [Int]) -> (start: Int, end: Int)? {
        
        let logitsCount = Int(startLogits.count)
        var bestSum = -Float.infinity
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
    
    private func featurizeCommon(question: String, context: String) -> ([Int], [Int], MLMultiArray) {
        let tokensQuestion = tokenizer.tokenizeToIds(text: question)
        var tokensContext = tokenizer.tokenizeToIds(text: context)
        if tokensQuestion.count + tokensContext.count + 3 > seqLen {
            /// This case is fairly rare in the dev set (183/10570),
            /// so we just keep only the start of the context in that case.
            /// In Python, we use a more complex sliding window approach.
            /// see `pytorch-transformers`.
            let toRemove = tokensQuestion.count + tokensContext.count + 3 - seqLen
            tokensContext.removeLast(toRemove)
        }
        
        let nPadding = seqLen - tokensQuestion.count - tokensContext.count - 3
        /// Sequence of input symbols. The sequence starts with a start token (101) followed by question tokens that are followed be a separator token (102) and the document tokens.The document tokens end with a separator token (102) and the sequenceis padded with 0 values to length 384.
        var allTokens: [Int] = []
        /// Would love to create it in a single Swift line but Xcode compiler fails...
        allTokens.append(
            tokenizer.tokenToId(token: "[CLS]")
        )
        allTokens.append(contentsOf: tokensQuestion)
        allTokens.append(
            tokenizer.tokenToId(token: "[SEP]")
        )
        allTokens.append(contentsOf: tokensContext)
        allTokens.append(
            tokenizer.tokenToId(token: "[SEP]")
        )
        allTokens.append(contentsOf: Array(repeating: 0, count: nPadding))
        let input_ids = MLMultiArray.from(allTokens, dims: 2)
        
        return (tokensQuestion, tokensContext, input_ids)
    }
    
    func featurizeTokensDistilled(question: String, context: String) -> distilbert_squad_384_FP16Input {
        let (_, _, input_ids) = featurizeCommon(question: question, context: context)
        return distilbert_squad_384_FP16Input(input_ids: input_ids)
    }
    
    //MARK: Vector Sum
    private func sum(x: [Float]) -> Float {
        return cblas_sasum(Int32(x.count), x, 1)
    }
    
    //MARK: Subtraction
    private func sub(x: [Float], y: [Float]) -> [Float] {
        var result = [Float](x)
        
        vDSP_vsub(y, 1, x, 1, &result, 1, vDSP_Length(x.count))
        return result
    }
    
    private func sub(x: [Float], c: Float) -> [Float] {
        var result = (1...x.count).map{_ in c}
        
        catlas_saxpby(Int32(x.count), 1.0, x, 1, -1.0, &result, 1)
        
        return result
    }
    
    //MARK: Division
    private func div(x: [Float], y: [Float]) -> [Float] {
        var results = [Float](repeating: 0.0, count: x.count)
        vvdivf(&results, x, y, [Int32(x.count)])
        
        return results
    }
    
    private func div(x: [Float], c: Float) -> [Float] {
        let divisor = [Float](repeating: c, count: x.count)
        var result = [Float](repeating: 0.0, count: x.count)
        
        vvdivf(&result, x, divisor, [Int32(x.count)])
        
        return result
    }
    
    //MARK: Special elementwise functions
    private func exp(x: [Float]) -> [Float] {
        var results = [Float](repeating: 0.0, count: x.count)
        vvexpf(&results, x, [Int32(x.count)])
        
        return results
    }
    //MARK: Softmax function
    private func softmax(z: [Float]) -> [Float] {
        let x = exp(x: sub(x: z, c: z.max()!))
        return div(x: x, c: sum(x: x))
    }

}

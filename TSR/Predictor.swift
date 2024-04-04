//
//  Predictor.swift
//  TSR
//
//  Created by Majed Hariri on 1/1/24.
//

import Foundation
import Vision
import UIKit
import SwiftUI
import CreateMLComponents


struct PredictionObject {
    var label : String
    var confidence : Double
}

protocol PredictorDelegate {
    func didUpdatePrediction(predictionObject : PredictionObject)
}

class Predictor {
    
    private let predictionWindowSize = 64
    private var posesWindow: [VNHumanBodyPoseObservation] = []
    private var exerciseClassifier: ExerciseClassifier?
    var delegate: PredictorDelegate?
    
    private let predictionQueue = DispatchQueue(label: "predictionQueue")
    private var isPredicting = false
    
    init() {
        do {
            self.exerciseClassifier = try ExerciseClassifier(configuration: MLModelConfiguration())
        } catch {
            print("Failed to load ExerciseClassifier model: \(error)")
        }
        posesWindow.reserveCapacity(128)
    }
    
    func estimateJumpingJacks(sampleBuffer: CMSampleBuffer) {
        let requestHandler = VNImageRequestHandler(cmSampleBuffer: sampleBuffer, orientation: .upMirrored)
        let request = VNDetectHumanBodyPoseRequest(completionHandler: handlePoseDetectionResult)
        do {
            try requestHandler.perform([request])
        } catch {
            print(error)
        }
    }
    
    private func handlePoseDetectionResult(request: VNRequest, error: Error?) {
        guard let observations = request.results as? [VNHumanBodyPoseObservation] else { return }
        guard let pose = observations.first else { return }
        
        predictionQueue.async {
            self.posesWindow.append(pose)
            
            if self.posesWindow.count >= self.predictionWindowSize && !self.isPredicting {
                self.isPredicting = true
                self.performPrediction()
            }
        }
    }
    
    private func performPrediction() {
        if !isPredicting {return}
        var didCallDelegate = false
        
        DispatchQueue.main.async {
            self.delegate?.didUpdatePrediction(predictionObject: PredictionObject(label: "Negative", confidence: 0.2))
        }
        
        guard let classifier = self.exerciseClassifier else { return }
        guard let posesMultiArray = preparePosesForPrediction(posesWindow) else { return }
        
        
        
        DispatchQueue.global(qos: .userInitiated).async {
            guard let prediction = try? classifier.prediction(poses: posesMultiArray) else { return }
            
            let label = prediction.label
            let confidence = prediction.labelProbabilities[label] ?? 0
            
            DispatchQueue.main.async {
                if didCallDelegate { return }
                didCallDelegate = true
                
                if label == "Jumping Jacks" && confidence >= 0.85 {
                    self.delegate?.didUpdatePrediction(predictionObject: PredictionObject(label: label, confidence: confidence))
                    print("Before cleaning the keepingCapacity : \(self.posesWindow.count)")
                    if self.posesWindow.count > 52 {
                        self.posesWindow.removeFirst(self.posesWindow.count - 20)
                        print("After cleaning the keepingCapacity : \(self.posesWindow.count)")
                    }else{
                        self.posesWindow.removeAll(keepingCapacity: true)
                        print("After cleaning the keepingCapacity : \(self.posesWindow.count)")
                    }
                } else {
                    self.delegate?.didUpdatePrediction(predictionObject: PredictionObject(label: "Negative", confidence: confidence))
                    if self.posesWindow.count > 2 {
                        
                        self.posesWindow.removeFirst(self.posesWindow.count / 3)
                        print("Cleaning half posesWindow : \(self.posesWindow.count)")
                    }
                }
                self.clearPosesAndResetPredictionFlag()
            }
        }
    }
    
    private func clearPosesAndResetPredictionFlag() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            self.delegate?.didUpdatePrediction(predictionObject: PredictionObject(label: "Negative", confidence: 0.2))
            self.isPredicting = false
        }
    }
    
    
    func preparePosesForPrediction(_ poses: [VNHumanBodyPoseObservation]) -> MLMultiArray? {
        let numberAvailableFrames = poses.count
        let numberObservationNeeded = predictionWindowSize
        var multiAraayBuffer = [MLMultiArray]()
        
        for frameIndex in 0..<min(numberAvailableFrames, numberObservationNeeded) {
            let pose = poses[frameIndex]
            do{
                let oneFrameMultiArray = try pose.keypointsMultiArray()
                multiAraayBuffer.append(oneFrameMultiArray)
            }catch{
                continue
            }
            
            if numberAvailableFrames < numberObservationNeeded {
                for _ in 0..<(numberObservationNeeded - numberAvailableFrames) {
                    do {
                        let oneFrameMultiArray = try MLMultiArray(shape: [1, 3, 18], dataType: .double)
                        try resetMultiArray(oneFrameMultiArray)
                        multiAraayBuffer.append(oneFrameMultiArray)
                    }catch{
                        continue
                    }
                }
            }
        }
        return MLMultiArray(concatenating: multiAraayBuffer, axis: 0, dataType: .float)
    }
    
    
    func resetMultiArray(_ multiArray: MLMultiArray) throws {
        let pointer = try UnsafeMutableBufferPointer<Double>(multiArray)
        pointer.initialize(repeating: 0.0)
    }
    
}

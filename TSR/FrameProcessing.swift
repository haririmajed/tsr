//
//  FrameProcessing.swift
//  TSR
//
//  Created by Majed Hariri on 1/1/24.
//

import Foundation
import SwiftUI
import AVFoundation
import CreateMLComponents

enum CameraAuthorizationStatus {
    case authorized
    case notAuthorized
    case notDetermined
}


class FrameProcessing : NSObject, ObservableObject, PredictorDelegate {
    @Published var streamingFrames : CGImage?
    @Published var predictionObject : PredictionObject?
    @Published var cameraAuthorizationStatus : CameraAuthorizationStatus = .notDetermined
    private var captureSession = AVCaptureSession()
    

    var predictor : Predictor = Predictor()
    
    override init() {
        super.init()
        predictor.delegate = self
        if checkPermission(){
            setupCamera()
            startCaptureSession()
        }
    }

    func takePhoto() -> CGImage? {
        guard let image = streamingFrames else {return nil}
        return image
    }

    
    
    func startCaptureSession() {
        DispatchQueue.global(qos: .background).async {
            self.captureSession.startRunning()
        }
    }
    
    func stopCaptureSession(){
        DispatchQueue.global(qos: .background).async {
            self.captureSession.stopRunning()
        }
    }
    
    func setupCamera(){
        guard let captureDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) else { return }
        guard let input = try? AVCaptureDeviceInput(device: captureDevice) else { return }
        guard captureSession.canAddInput(input) else {return}
        captureDevice.setMaxSupportedFrameRate()
        captureSession.sessionPreset = .medium
        captureSession.addInput(input)
        
        
        let dataOutput = AVCaptureVideoDataOutput()
        dataOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "videoQueue"))
        captureSession.addOutput(dataOutput)
        dataOutput.connection(with: .video)?.videoOrientation = .portrait
        dataOutput.connection(with: .video)?.automaticallyAdjustsVideoMirroring = false
        dataOutput.connection(with: .video)?.isVideoMirrored = true
        dataOutput.alwaysDiscardsLateVideoFrames = true
        
    }
    
    
    
    func didUpdatePrediction(predictionObject: PredictionObject) {
        self.predictionObject = predictionObject
    }
    
    
}

extension FrameProcessing : AVCaptureVideoDataOutputSampleBufferDelegate {
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        DispatchQueue.main.async {
            guard let imageBuffer = self.imageFromSampleBuffer(sampleBuffer: sampleBuffer) else {return}
            self.streamingFrames = imageBuffer
        }
    }
    
    func imageFromSampleBuffer(sampleBuffer : CMSampleBuffer) -> CGImage? {
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {return nil}
        let ciImage = CIImage(cvPixelBuffer: imageBuffer)
        let context = CIContext()
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else {return nil}
        predictor.estimateJumpingJacks(sampleBuffer: sampleBuffer)
        return cgImage
    }
    
    
    func checkPermission() -> Bool {
        var permission = false
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        switch status {
        case .authorized:
            permission = true
            DispatchQueue.main.async {
                self.cameraAuthorizationStatus = .authorized
            }
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { (granted) in
                if granted {
                    permission = true
                    DispatchQueue.main.async {
                        self.cameraAuthorizationStatus = .authorized
                    }
                }else{
                    permission = false
                    DispatchQueue.main.async {
                        self.cameraAuthorizationStatus = .notAuthorized
                    }
                }
            }
        default:
            permission = false
            DispatchQueue.main.async {
                self.cameraAuthorizationStatus = .notAuthorized
            }
        }
        return permission
    }
    
}


extension AVCaptureDevice {
    func setMaxSupportedFrameRate() {
        guard let range = activeFormat.videoSupportedFrameRateRanges.first else {
            print("Could not retrieve frame rate range!")
            return
        }

        do {
            try lockForConfiguration()
            let maxFrameRate = range.maxFrameRate
            activeVideoMinFrameDuration = CMTimeMake(value: 1, timescale: Int32(maxFrameRate))
            activeVideoMaxFrameDuration = CMTimeMake(value: 1, timescale: Int32(maxFrameRate))
            unlockForConfiguration()
        } catch {
            print("LockForConfiguration failed with error: \(error.localizedDescription)")
        }
    }
}

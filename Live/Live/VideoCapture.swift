//
//  VideoCapture.swift
//  Live
//
//  Created by Migu on 2016/12/22.
//  Copyright © 2016年 VictorChee. All rights reserved.
//

import UIKit
import AVFoundation

final class VideoCapture: NSObject {
    fileprivate let captureQueue = DispatchQueue(label: "VideoCapture")
    
    var videoPreviewView = VideoPreviewView()
    
    var session: AVCaptureSession!
    fileprivate var captureOutput: AVCaptureVideoDataOutput!
    fileprivate var captureInput: AVCaptureDeviceInput?
    fileprivate var outputHandler: OutputHandler?

    var videoOrientation = AVCaptureVideoOrientation.portrait {
        didSet {
            if videoOrientation == oldValue { return }
            configureVideoOrientation()
        }
    }
    
    fileprivate func configureVideoOrientation() {
        if let connection = videoPreviewView.layer.value(forKey: "connection") as? AVCaptureConnection {
            if connection.isVideoOrientationSupported {
                connection.videoOrientation = videoOrientation
            }
        }
        
        guard let output = captureOutput else { return }
        
        if let connection = output.connection(withMediaType: AVMediaTypeVideo) {
            if connection.isVideoOrientationSupported {
                connection.videoOrientation = videoOrientation
            }
        }
    }
    
    fileprivate func configureVideoPreview() {
        videoPreviewView.session = session
    }
    
    fileprivate func configureCaptureOutput() {
        guard let session = self.session else { return }
        if captureOutput != nil {
            session.removeOutput(captureOutput)
        }
        
        captureOutput = AVCaptureVideoDataOutput()
        captureOutput.alwaysDiscardsLateVideoFrames = true
        captureOutput.videoSettings = [(kCVPixelBufferPixelFormatTypeKey as String): NSNumber(value: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange)]
        captureOutput.setSampleBufferDelegate(self, queue: captureQueue)
        if session.canAddOutput(captureOutput) {
            session.addOutput(captureOutput)
        }
        
        for connection in captureOutput.connections {
            guard let connection = connection as? AVCaptureConnection else { continue }
            if connection.isVideoOrientationSupported {
                connection.videoOrientation = videoOrientation
            }
        }
    }
    
    fileprivate func configureCaptureInput() {
        guard let session = self.session else { return }
        
        do {
            if captureInput != nil {
                session.removeInput(captureInput)
            }
            
            let device = AVCaptureDevice.defaultDevice(withMediaType: AVMediaTypeVideo)
            captureInput = try AVCaptureDeviceInput(device: device)
            if session.canAddInput(captureInput) {
                session.addInput(captureInput)
            }
        } catch {
            print(error)
        }
    }
    
    fileprivate func configureSession() {
        guard let session = self.session else { return }
        session.beginConfiguration()
        if session.canSetSessionPreset(AVCaptureSessionPreset1280x720) {
            session.sessionPreset = AVCaptureSessionPreset1280x720
        }
        session.commitConfiguration()
    }
    
    func attachCamera() {
        configureCaptureOutput()
        configureCaptureInput()
        configureSession()
        configureVideoOrientation()
        configureVideoPreview()
    }
    
    func output(outputHandler: @escaping OutputHandler) {
        self.outputHandler = outputHandler
    }
}

extension VideoCapture: AVCaptureVideoDataOutputSampleBufferDelegate {
    typealias OutputHandler = (_ sampleBuffer: CMSampleBuffer) -> Void
    
    func captureOutput(_ captureOutput: AVCaptureOutput!, didOutputSampleBuffer sampleBuffer: CMSampleBuffer!, from connection: AVCaptureConnection!) {
        self.outputHandler?(sampleBuffer)
    }
}

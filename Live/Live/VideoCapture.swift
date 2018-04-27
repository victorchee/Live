//
//  VideoCapture.swift
//  Capture
//
//  Created by VictorChee on 2016/12/22.
//  Copyright © 2016年 VictorChee. All rights reserved.
//

import UIKit
import AVFoundation

final class VideoCapture: NSObject {
    fileprivate let captureQueue = DispatchQueue(label: "VideoCapture")
    
    let videoPreviewView = VideoPreviewView()
    
    /// 由外部传入，因为要和Audio Capture共享同一个sesstion
    var session: AVCaptureSession?
    fileprivate var captureOutput: AVCaptureVideoDataOutput?
    fileprivate var captureInput: AVCaptureDeviceInput?
    
    fileprivate var outputHandler: OutputHandler?

    var videoOrientation = AVCaptureVideoOrientation.portrait {
        didSet {
            if videoOrientation != oldValue {
                configureVideoOrientation()
            }
        }
    }
    
    // MARK: - Configurations
    
    fileprivate func configureVideoOrientation() {
        if let connection = videoPreviewView.layer.value(forKey: "connection") as? AVCaptureConnection, connection.isVideoOrientationSupported {
            connection.videoOrientation = videoOrientation
        }
        
        if let output = captureOutput, let connection = output.connection(with: AVMediaType.video), connection.isVideoOrientationSupported {
            connection.videoOrientation = videoOrientation
        }
    }
    
    fileprivate func configureVideoPreview() {
        videoPreviewView.session = session
    }
    
    fileprivate func configureCaptureOutput() {
        guard let session = self.session else { return }
        if let captureOutput = self.captureOutput {
            session.removeOutput(captureOutput)
        }
        
        captureOutput = AVCaptureVideoDataOutput()
        captureOutput!.alwaysDiscardsLateVideoFrames = true
        captureOutput!.videoSettings = [(kCVPixelBufferPixelFormatTypeKey as String): NSNumber(value: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange)]
        captureOutput!.setSampleBufferDelegate(self, queue: captureQueue)
        if session.canAddOutput(captureOutput!) {
            session.addOutput(captureOutput!)
        }
        
        for connection in captureOutput!.connections {
            guard let connection = connection as? AVCaptureConnection else { continue }
            if connection.isVideoOrientationSupported {
                connection.videoOrientation = videoOrientation
            }
        }
    }
    
    fileprivate func configureCaptureInput() {
        guard let session = self.session else { return }
        if let captureInput = self.captureInput {
            session.removeInput(captureInput)
        }
        
        do {
            let device = AVCaptureDevice.default(for: AVMediaType.video)
            captureInput = try AVCaptureDeviceInput(device: device!)
            if session.canAddInput(captureInput!) {
                session.addInput(captureInput!)
            }
        } catch {
            print("Video Capture Input Error: \(error)")
        }
    }
    
    fileprivate func configureSession() {
        guard let session = self.session else { return }
        session.beginConfiguration()
        if session.canSetSessionPreset(AVCaptureSession.Preset.hd1280x720) {
            session.sessionPreset = AVCaptureSession.Preset.hd1280x720
        }
        session.commitConfiguration()
    }
    
    // MARK: - Methods
    
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
    
    func captureOutput(_ captureOutput: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        self.outputHandler?(sampleBuffer) // 未编码的数据
    }
}

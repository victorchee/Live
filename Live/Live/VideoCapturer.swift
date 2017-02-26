//
//  VideoCapturer.swift
//  Live
//
//  Created by Migu on 2016/12/22.
//  Copyright © 2016年 VictorChee. All rights reserved.
//

import UIKit
import AVFoundation

final class VideoCapturer: NSObject {
    fileprivate let capturerQueue = DispatchQueue(label: "VideoCapturer")
    static let supportedSettingsKeys = [
        "devicePosition",
        "fps",
        "sessionPreset",
        "continuousAutofocus",
        "continuousExposure",
    ]
    var devicePosition = AVCaptureDevicePosition.back {
        didSet {
            if devicePosition == oldValue { return }
            capturerQueue.async {
                self.configureCaptureInput()
                self.configureVideoOrientation()
//                self.configureVideoFPS()
            }
        }
    }
    var videoOrientation = AVCaptureVideoOrientation.portrait {
        didSet {
            if videoOrientation == oldValue { return }
            configureVideoOrientation()
        }
    }
    var fps: Float64 = 25 {
        didSet {
            if fps == oldValue { return }
            capturerQueue.async {
                self.configureVideoFPS()
            }
        }
    }
    var sessionPreset: String = AVCaptureSessionPreset1280x720 {
        didSet {
            if sessionPreset == oldValue { return }
            capturerQueue.async {
                self.configureSession()
            }
        }
    }
    var continuousExposure = false {
        didSet {
            if continuousExposure == oldValue { return }
            capturerQueue.async {
                self.configureExposure()
            }
        }
    }
    var continuousAutofocus = false {
        didSet {
            if continuousAutofocus == oldValue { return }
            capturerQueue.async {
                self.configureAutofocus()
            }
        }
    }
    
    var videoPreviewView = VideoPreviewView()
    
    var session: AVCaptureSession!
    fileprivate var captureOutput: AVCaptureVideoDataOutput!
    fileprivate var captureInput: AVCaptureDeviceInput?
    fileprivate var outputHandler: OutputHandler?
    
    private func getActualFPS(fps: Float64, device: AVCaptureDevice) -> (fps: Float64, duration: CMTime)? {
        // @see https://www.objccn.io/issue-23-1/
        var durations = [CMTime]()
        var frameRates = [Float64]()
        
        for object in device.activeFormat.videoSupportedFrameRateRanges {
            guard let range = object as? AVFrameRateRange else { continue }
            if range.minFrameRate == range.maxFrameRate {
                durations.append(range.minFrameDuration)
                frameRates.append(range.maxFrameRate)
                continue
            }
            // 说明 fps 在支持的范围之内，返回
            if range.minFrameRate <= fps && fps <= range.maxFrameRate {
                return (fps, CMTimeMake(100, Int32(100*fps)))
            }
            // 若 fps不在支持的范围之内，则 get到支持的最大或者 最小的 fps，并返回
            let actualFPS = max(range.minFrameRate, min(range.maxFrameRate, fps))
            return (actualFPS, CMTimeMake(100, Int32(100*actualFPS)))
        }
        
        var diff = [Float64]()
        for frameRate in frameRates {
            diff.append(abs(frameRate-fps))
        }
        if let minElement = diff.min() {
            for i in 0..<diff.count {
                if diff[i] == minElement {
                    return (frameRates[i], durations[i])
                }
            }
        }
        return nil
    }
    
    private func deviceWithPosition(_ postion: AVCaptureDevicePosition) -> AVCaptureDevice? {
        let deviceSession =  AVCaptureDeviceDiscoverySession(deviceTypes: [.builtInDualCamera, .builtInTelephotoCamera, .builtInWideAngleCamera], mediaType: AVMediaTypeVideo, position: postion)
        return deviceSession?.devices.first
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
    
    fileprivate func configureVideoFPS() {
        guard let device = self.captureInput?.device, let data = self.getActualFPS(fps: fps, device: device) else { return }
        fps = data.fps
        do {
            try device.lockForConfiguration()
            device.activeVideoMinFrameDuration = data.duration
            device.activeVideoMaxFrameDuration = data.duration
            device.unlockForConfiguration()
        } catch {
            print(error)
        }
    }
    
    fileprivate func configureVideoPreview() {
        videoPreviewView.session = session
    }
    
    fileprivate func configureExposure() {
        let exposureMode = continuousExposure ? AVCaptureExposureMode.continuousAutoExposure : .autoExpose
        guard let device = self.captureInput?.device, device.isExposureModeSupported(exposureMode) else { return }
        do {
            try device.lockForConfiguration()
            device.exposureMode = exposureMode
            device.unlockForConfiguration()
        } catch {
            print(error)
        }
    }
    
    fileprivate func configureAutofocus() {
        let focusMode = continuousAutofocus ? AVCaptureFocusMode.continuousAutoFocus : .autoFocus
        guard let device = self.captureInput?.device, device.isFocusModeSupported(focusMode) else { return }
        do {
            try device.lockForConfiguration()
            device.focusMode = focusMode
            device.unlockForConfiguration()
        } catch {
            print(error)
        }
    }
    
    fileprivate func configureCaptureOutput() {
        guard let session = self.session else { return }
        if captureOutput != nil {
            session.removeOutput(captureOutput)
        }
        
        captureOutput = AVCaptureVideoDataOutput()
        captureOutput.alwaysDiscardsLateVideoFrames = true
        captureOutput.videoSettings = [(kCVPixelBufferPixelFormatTypeKey as String): NSNumber(value: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange)]
        captureOutput.setSampleBufferDelegate(self, queue: capturerQueue)
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
        guard let device = deviceWithPosition(devicePosition) else { return }
        guard let session = self.session else { return }
        
        do {
            if captureInput != nil {
                session.removeInput(captureInput)
            }
            
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
        if session.canSetSessionPreset(sessionPreset) {
            session.sessionPreset = sessionPreset
        }
        session.commitConfiguration()
    }
    
    func attachCamera() {
        configureCaptureOutput()
        configureCaptureInput()
        configureVideoFPS()
        configureSession()
        configureVideoOrientation()
        configureVideoPreview()
    }
    
    func output(outputHandler: @escaping OutputHandler) {
        self.outputHandler = outputHandler
    }
}

extension VideoCapturer: AVCaptureVideoDataOutputSampleBufferDelegate {
    typealias OutputHandler = (_ sampleBuffer: CMSampleBuffer) -> Void
    
    func captureOutput(_ captureOutput: AVCaptureOutput!, didOutputSampleBuffer sampleBuffer: CMSampleBuffer!, from connection: AVCaptureConnection!) {
        self.outputHandler?(sampleBuffer)
    }
}

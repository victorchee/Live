//
//  AudioCapture.swift
//  Live
//
//  Created by VictorChee on 2016/12/22.
//  Copyright © 2016年 VictorChee. All rights reserved.
//

import UIKit
import AVFoundation

final class AudioCapture: NSObject {
    fileprivate let captureQueue = DispatchQueue(label: "AudioCaptureQueue")
    
    /// 由外部传入，因为要和Video Capture共享同一个sesstion
    var session: AVCaptureSession?
    fileprivate var captureOutput: AVCaptureAudioDataOutput?
    fileprivate var captureInput: AVCaptureDeviceInput?
    
    fileprivate var outputHandler: OutputHandler?
    
    // MARK: - Configurations
    
    fileprivate func configureCaptureOutput() {
        guard let session = self.session else { return }
        if let captureOutput = self.captureOutput {
            captureOutput.setSampleBufferDelegate(nil, queue: nil)
            session.removeOutput(captureOutput)
        }
        
        captureOutput = AVCaptureAudioDataOutput()
        captureOutput!.setSampleBufferDelegate(self, queue: captureQueue)
        if session.canAddOutput(captureOutput) {
            session.addOutput(captureOutput)
        }
    }
    
    fileprivate func configureCaptureInput() {
        guard let session = self.session else { return }
        if let captureInput = self.captureInput {
            session.removeInput(captureInput)
        }
        
        do {
            let device = AVCaptureDevice.defaultDevice(withMediaType: AVMediaTypeAudio)
            captureInput = try AVCaptureDeviceInput(device: device)
            if session.canAddInput(captureInput) {
                session.addInput(captureInput)
            }
        } catch {
            print("Audio Capture Input Error: \(error)")
        }
    }
    
    // MARK: - Methods
    
    func attachMicrophone() {
        configureCaptureOutput()
        configureCaptureInput()
    }
    
    func output(outputHandler: @escaping OutputHandler) {
        self.outputHandler = outputHandler
    }
}

extension AudioCapture: AVCaptureAudioDataOutputSampleBufferDelegate {
    typealias OutputHandler = (_ sampleBuffer: CMSampleBuffer) -> Void
    
    func captureOutput(_ captureOutput: AVCaptureOutput!, didOutputSampleBuffer sampleBuffer: CMSampleBuffer!, from connection: AVCaptureConnection!) {
        self.outputHandler?(sampleBuffer) // 未编码的PCM数据
    }
}

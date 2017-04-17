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
    
    var session: AVCaptureSession!
    var captureOutput: AVCaptureAudioDataOutput!
    var captureInput: AVCaptureDeviceInput!
    
    fileprivate var outputHandler: OutputHandler?
    
    fileprivate func configureCaptureOutput() {
        guard let session = self.session else { return }
        if captureOutput != nil {
            captureOutput.setSampleBufferDelegate(nil, queue: nil)
            session.removeOutput(captureOutput)
        }
        
        captureOutput = AVCaptureAudioDataOutput()
        captureOutput.setSampleBufferDelegate(self, queue: captureQueue)
        if session.canAddOutput(captureOutput) {
            session.addOutput(captureOutput)
        }
    }
    
    fileprivate func configureCaptureInput() {
        guard let device = AVCaptureDevice.defaultDevice(withMediaType: AVMediaTypeAudio) else { return }
        guard let session = self.session else { return }
        
        do {
            captureInput = try AVCaptureDeviceInput(device: device)
            session.automaticallyConfiguresApplicationAudioSession = true
            if session.canAddInput(captureInput) {
                session.addInput(captureInput)
            }
        } catch {
            print(error)
        }
    }
    
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
        self.outputHandler?(sampleBuffer) // 未编码的数据
    }
}

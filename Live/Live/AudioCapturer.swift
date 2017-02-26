//
//  AudioCapturer.swift
//  Live
//
//  Created by Migu on 2016/12/22.
//  Copyright © 2016年 VictorChee. All rights reserved.
//

import UIKit
import AVFoundation

final class AudioCapturer: NSObject {
    fileprivate let capturerQueue = DispatchQueue(label: "AudioCapturerQueue")
    
    var session: AVCaptureSession!
    var captureOutput: AVCaptureAudioDataOutput!
    var captureInput: AVCaptureDeviceInput!
    
    fileprivate var outputHandler: OutputHandler?
    
    fileprivate func configureCapturerOutput() {
        guard let session = self.session else { return }
        if captureOutput != nil {
            captureOutput.setSampleBufferDelegate(nil, queue: nil)
            session.removeOutput(captureOutput)
        }
        
        captureOutput = AVCaptureAudioDataOutput()
        captureOutput.setSampleBufferDelegate(self, queue: capturerQueue)
        if session.canAddOutput(captureOutput) {
            session.addOutput(captureOutput)
        }
    }
    
    fileprivate func configureCapturerInput() {
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
        configureCapturerOutput()
        configureCapturerInput()
    }
    
    func output(outputHandler: @escaping OutputHandler) {
        self.outputHandler = outputHandler
    }
}

extension AudioCapturer: AVCaptureAudioDataOutputSampleBufferDelegate {
    typealias OutputHandler = (_ sampleBuffer: CMSampleBuffer) -> Void
    
    func captureOutput(_ captureOutput: AVCaptureOutput!, didOutputSampleBuffer sampleBuffer: CMSampleBuffer!, from connection: AVCaptureConnection!) {
        self.outputHandler?(sampleBuffer)
    }
}

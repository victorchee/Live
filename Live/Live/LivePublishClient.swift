//
//  LivePublishClient.swift
//  Live
//
//  Created by VictorChee on 2016/12/22.
//  Copyright © 2016年 VictorChee. All rights reserved.
//

import UIKit
import AVFoundation
import RTMP

class LivePublishClient: NSObject {
    fileprivate let publishClientQueue = DispatchQueue(label: "LivePublishClientQueue")
    fileprivate var isPublishReady = false
    fileprivate var videoOrientation = AVCaptureVideoOrientation.portrait {
        didSet {
            if videoOrientation == oldValue { return }
            videoCapture.videoOrientation = videoOrientation
            videoEncoder.videoOrientation = videoOrientation
        }
    }
    fileprivate let videoCapture = VideoCapture()
    fileprivate let audioCapture = AudioCapture()
    fileprivate let captureSession = AVCaptureSession()
    fileprivate let videoEncoder = AVCEncoder()
    fileprivate let audioEncoder = AACEncoder()
    fileprivate var muxer = RTMPMuxer()
    fileprivate var rtmpPublisher = RTMPPublishClient()
    public var videoPreviewView: VideoPreviewView {
        return videoCapture.videoPreviewView
    }
    public var videoEncoderSettings: [String: Any] {
        get {
            return videoEncoder.dictionaryWithValues(forKeys: AVCEncoder.supportedSettingsKeys)
        }
        set {
            videoEncoder.setValuesForKeys(newValue)
        }
    }
    public var audioEncoderSettings: [String: Any] {
        get {
            return audioEncoder.dictionaryWithValues(forKeys: AACEncoder.supportedSettingsKeys)
        }
        set {
            audioEncoder.setValuesForKeys(newValue)
        }
    }
    
    public override init() {
        super.init()
        setupRTMP()
        setupCapture()
        setupEncode()
    }
    
    public func startPublish(toUrl rtmpUrl: String) {
        if isPublishReady { return }
        publishClientQueue.async {
            self.captureSession.startRunning()
            self.rtmpPublisher.setMediaMetaData(self.audioEncoder.metaData)
            self.rtmpPublisher.setMediaMetaData(self.videoEncoder.metaData)
            self.rtmpPublisher.connect(rtmpUrl: rtmpUrl)
            self.videoEncoder.run()
            self.audioEncoder.run()
        }
    }
    
    private func setupRTMP() {
        rtmpPublisher.delegate = self
        muxer.delegate = self
    }
    
    private func setupCapture() {
        listenOrientationDidChangeNotification()
        
        audioCapture.session = captureSession
        audioCapture.output { (sampleBuffer) in
            self.handleAudioCaptureBuffer(sampleBuffer)
        }
        audioCapture.attachMicrophone()
        
        videoCapture.session = captureSession
        videoCapture.output { (sampleBuffer) in
            self.handleVideoCaptureBuffer(sampleBuffer)
        }
        videoCapture.attachCamera()
    }
    
    private func setupEncode() {
        audioEncoder.delegate = self
        videoEncoder.delegate = self
    }
    
    private func handleAudioCaptureBuffer(_ sampleBuffer: CMSampleBuffer) {
        guard isPublishReady else { return }
        audioEncoder.encode(sampleBuffer: sampleBuffer)
    }
    
    private func handleVideoCaptureBuffer(_ sampleBuffer: CMSampleBuffer) {
        guard isPublishReady else { return }
        videoEncoder.encode(sampleBuffer: sampleBuffer)
    }
    
    public func stop() {
        guard isPublishReady else { return }
        publishClientQueue.async {
            self.captureSession.stopRunning()
            self.videoEncoder.stop()
            self.audioEncoder.stop()
            self.rtmpPublisher.stop()
            self.isPublishReady = false
        }
    }
}

extension LivePublishClient: RTMPPublisherDelegate {
    func publishStreamHasDone() {
        isPublishReady = true
    }
}

extension LivePublishClient: AVCEncoderDelegate {
    func didGetAVCFormatDescription(_ formatDescription: CMFormatDescription?) {
        muxer.muxAVCFormatDescription(formatDescription: formatDescription)
    }
    
    func didGetAVCSampleBuffer(_ sampleBuffer: CMSampleBuffer) {
        muxer.muxAVCSampleBuffer(sampleBuffer: sampleBuffer)
    }
}

extension LivePublishClient: AACEncoderDelegate {
    func didGetAACFormatDescription(_ formatDescription: CMFormatDescription?) {
        muxer.muxAACFormatDescription(formatDescription: formatDescription)
    }
    
    func didGetAACSampleBuffer(_ sampleBuffer: CMSampleBuffer?) {
        muxer.muxAACSampleBuffer(sampleBuffer: sampleBuffer)
    }
}

extension LivePublishClient: RTMPMuxerDelegate {
    func sampleOutput(audio buffer: NSData, timestamp: Double) {
        var payload = [UInt8](repeating: 0x00, count: buffer.length)
        buffer.getBytes(&payload, length: payload.count)
        rtmpPublisher.publishAudio(payload, timestamp: UInt32(timestamp))
    }
    
    func sampleOutput(video buffer: NSData, timestamp: Double) {
        var payload = [UInt8](repeating: 0x00, count: buffer.length)
        buffer.getBytes(&payload, length: payload.count)
        rtmpPublisher.publishVideo(payload, timestamp: UInt32(timestamp))
    }
}

extension LivePublishClient {
    fileprivate func listenOrientationDidChangeNotification() {
        NotificationCenter.default.addObserver(forName: NSNotification.Name.UIDeviceOrientationDidChange, object: nil, queue: OperationQueue.main) { (notification) in
            var deviceOrientation = UIDeviceOrientation.unknown
            if let device = notification.object as? UIDevice {
                deviceOrientation = device.orientation
            }
            
            func getAVCaptureVideoOrientation(_ orientaion: UIDeviceOrientation) -> AVCaptureVideoOrientation? {
                switch orientaion {
                case .portrait:
                    return .portrait
                case .portraitUpsideDown:
                    return .portraitUpsideDown
                case .landscapeLeft:
                    return .landscapeRight
                case .landscapeRight:
                    return .landscapeLeft
                default:
                    return nil
                }
            }
            
            if let orientation = getAVCaptureVideoOrientation(deviceOrientation), orientation != self.videoOrientation {
                self.videoOrientation = orientation
            }
        }
    }
}

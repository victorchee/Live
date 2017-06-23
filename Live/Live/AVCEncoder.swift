//
//  AVCEncoder.swift
//  Live
//
//  Created by VictorChee on 2016/12/22.
//  Copyright © 2016年 VictorChee. All rights reserved.
//

import UIKit
import VideoToolbox
import AVFoundation

protocol AVCEncoderDelegate: class {
    func didGetAVCFormatDescription(_ formatDescription: CMFormatDescription?)
    func didGetAVCSampleBuffer(_ sampleBuffer: CMSampleBuffer)
}

final class AVCEncoder: NSObject {
    static let supportedSettingsKeys = [
        "width",
        "height",
        "fps",
        "bitrate",
        "keyFrameIntervalDuration",
    ]
    fileprivate var encoderQueue = DispatchQueue(label: "AVCEncoderQueue")
    var metaData: [String : Any] {
        var metaData = [String : Any]()
        metaData["duration"] = keyFrameIntervalDuration // not sure
        metaData["width"] = width
        metaData["height"] = height
        metaData["videodatarate"] = bitrate//bitrate
        metaData["framerate"] = fps // fps
        metaData["videocodecid"] = 7// avc is 7
        return metaData
    }
    
    /* encoder session rely on width and height ,when it changed we must regenerate the session */
    var width: Int32 = 1280 {
        didSet {
            if self.width == oldValue { return }
            encoderQueue.async {
                if self.session != nil { self.configureSession() }
            }
        }
    }
    
    var height: Int32 = 720 {
        didSet {
            if self.height == oldValue { return }
            encoderQueue.async {
                if self.session != nil { self.configureSession() }
            }
        }
    }
    
    var videoOrientation = AVCaptureVideoOrientation.portrait {
        didSet {
            if self.videoOrientation != oldValue {
                (self.width, self.height) = (self.height, self.width)
            }
        }
    }
    
    var fps: Float64 = 25 {
        didSet {
            if self.fps != oldValue {
                encoderQueue.async {
                    if let session = self.session {
                        VTSessionSetProperty(session, kVTCompressionPropertyKey_MaxKeyFrameInterval, self.fps as CFTypeRef)
                        VTSessionSetProperty(session, kVTCompressionPropertyKey_ExpectedFrameRate, self.fps as CFTypeRef)
                    }
                }
            }
        }
    }
    
    /// @see about bitrate: https://zh.wikipedia.org/wiki/比特率
    var bitrate: UInt32 = 200 * 1000 {
        didSet {
            if self.bitrate != oldValue {
                encoderQueue.async {
                    if let session = self.session {
                        VTSessionSetProperty(session, kVTCompressionPropertyKey_AverageBitRate, CFNumberCreate(nil, .sInt32Type, &self.bitrate))
                    }
                }
            }
        }
    }
    
    var keyFrameIntervalDuration: Double = 2.0 {
        didSet {
            if self.keyFrameIntervalDuration != oldValue {
                encoderQueue.async {
                    if let session = self.session {
                        VTSessionSetProperty(session, kVTCompressionPropertyKey_MaxKeyFrameIntervalDuration, CFNumberCreate(nil, .doubleType, &self.keyFrameIntervalDuration))
                    }
                }
            }
        }
    }
    
    weak var delegate: AVCEncoderDelegate?
    
    fileprivate var session: VTCompressionSession?
    fileprivate var formatDescription: CMFormatDescription?
    
    /// 编码成功回调
    fileprivate var callback: VTCompressionOutputCallback = {(
        outputCallbackRefCon:UnsafeMutableRawPointer?,
        sourceFrameRefCon:UnsafeMutableRawPointer?,
        status:OSStatus,
        infoFlags:VTEncodeInfoFlags,
        sampleBuffer:CMSampleBuffer?
        ) in
        // 编码完成的数据
        guard let sampleBuffer = sampleBuffer, status == noErr else { return }
        let encoder = unsafeBitCast(outputCallbackRefCon, to: AVCEncoder.self)
        let isKeyFrame = !CFDictionaryContainsKey(unsafeBitCast(CFArrayGetValueAtIndex(CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, true), 0), to: CFDictionary.self), unsafeBitCast(kCMSampleAttachmentKey_NotSync, to: UnsafeRawPointer.self))
        if isKeyFrame {
            let description = CMSampleBufferGetFormatDescription(sampleBuffer)
            if !CMFormatDescriptionEqual(description, encoder.formatDescription) {
                encoder.delegate?.didGetAVCFormatDescription(description)
                encoder.formatDescription = description
            }
        }
        encoder.delegate?.didGetAVCSampleBuffer(sampleBuffer)
    }
    
    fileprivate func configureSession() {
        if let session = self.session {
            VTCompressionSessionInvalidate(session)
            self.session = nil
        }
        let attributes: [NSString: Any] = [
            kCVPixelBufferPixelFormatTypeKey: Int(kCVPixelFormatType_420YpCbCr8BiPlanarFullRange),
            kCVPixelBufferIOSurfacePropertiesKey: [:],
            kCVPixelBufferOpenGLESCompatibilityKey: true,
            kCVPixelBufferHeightKey: NSNumber(value: height),
            kCVPixelBufferWidthKey: NSNumber(value: width),
        ]
        VTCompressionSessionCreate(kCFAllocatorDefault, height, width, kCMVideoCodecType_H264, nil, attributes as CFDictionary?, nil, callback, unsafeBitCast(self, to: UnsafeMutableRawPointer.self), &session) // 宽和高设置反了，只能看到视频中间部分图像
        
        let profileLevel = kVTProfileLevel_H264_Baseline_3_1 as String
        let isBaseline = profileLevel.contains("Baseline")
        
        var properties: [NSString: Any] = [
            kVTCompressionPropertyKey_RealTime: kCFBooleanTrue,
            kVTCompressionPropertyKey_ProfileLevel: profileLevel,
            kVTCompressionPropertyKey_AverageBitRate: Int(bitrate), // bit rate.
            kVTCompressionPropertyKey_ExpectedFrameRate: NSNumber(value: fps), // frame rate.
            kVTCompressionPropertyKey_MaxKeyFrameIntervalDuration: NSNumber(value: keyFrameIntervalDuration), // key frame interval.
            kVTCompressionPropertyKey_AllowFrameReordering: !isBaseline,
            kVTCompressionPropertyKey_PixelTransferProperties: [
                "ScalingMode": "Trim"]
        ]
        if !isBaseline {
            properties[kVTCompressionPropertyKey_H264EntropyMode] = kVTH264EntropyMode_CABAC
        }
        if session != nil {
            VTSessionSetProperties(session!, properties as CFDictionary)
        }
    }
    
    fileprivate func enableSession() {
        guard let session = session else { return }
        VTCompressionSessionPrepareToEncodeFrames(session)
    }
    
    fileprivate func disableSession() {
        if let session = self.session {
            VTCompressionSessionInvalidate(session)
        }
        self.session = nil
        formatDescription = nil // 必须置空，否则，再次推流的时候不会发送sps, pps，在某些服务器上不能播放
    }
    
    func encode(sampleBuffer: CMSampleBuffer) {
        guard let session = self.session else { return }
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let presentationTimestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        let duration = CMSampleBufferGetDuration(sampleBuffer)
        var flags = VTEncodeInfoFlags()
        VTCompressionSessionEncodeFrame(session, imageBuffer, presentationTimestamp, duration, nil, nil, &flags)
    }
    
    func run() {
        configureSession()
        enableSession()
    }
    
    func stop() {
        disableSession()
    }
}

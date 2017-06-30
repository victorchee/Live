//
//  AACEncoder.swift
//  Capture
//
//  Created by VictorChee on 2016/12/22.
//  Copyright © 2016年 VictorChee. All rights reserved.
//

/**
 - seealso:
 - https://developer.apple.com/library/ios/technotes/tn2236/_index.html
 - https://developer.apple.com/library/ios/documentation/AudioVideo/Conceptual/MultimediaPG/UsingAudio/UsingAudio.html
 */

import Foundation
import AVFoundation

protocol AACEncoderDelegate: class {
    func didGetAACFormatDescription(_ formatDescription: CMFormatDescription?)
    func didGetAACSampleBuffer(_ sampleBuffer: CMSampleBuffer?)
}

final class AACEncoder: NSObject {
    fileprivate let aacEncoderQueue = DispatchQueue(label: "AACEncoder")
    fileprivate var isRunning = false
    weak var delegate: AACEncoderDelegate?
    static let supportedSettingsKeys = [
        "muted",
        "bitrate",
        "profile",
        "sampleRate", // 暂不支持
    ]
    var metaData: [String: Any] {
        var metaData = [String: Any]()
        metaData["audiodatarate"] = bitrate
        metaData["audiosamplerate"] = 44100 // audio sample rate
        metaData["audiosamplesize"] = 16
        metaData["stereo"] = false //立体声（双通道）
        metaData["audiocodecid"] = 10
        return metaData
    }
    var muted = false
    var bitrate: UInt32 = 32*1024 {
        didSet {
            aacEncoderQueue.async {
                guard let converter = self._converter else { return }
                var bitrate: UInt32 = self.bitrate * self.inDestinationFormat.mChannelsPerFrame
                AudioConverterSetProperty(converter, kAudioConverterEncodeBitRate, UInt32(MemoryLayout<UInt32>.size), &bitrate)
            }
        }
    }
    fileprivate var profile = UInt32(MPEG4ObjectID.AAC_LC.rawValue)
    /// 关于音频描述信息的 转换后的AAC相关的包
    fileprivate var formatDescription: CMFormatDescription? {
        didSet {
            if !CMFormatDescriptionEqual(formatDescription, oldValue) {
                delegate?.didGetAACFormatDescription(formatDescription)
            }
        }
    }
    
    fileprivate var currentBufferList: UnsafeMutableAudioBufferListPointer? = nil
    fileprivate var maximumBuffers = 1
    fileprivate var bufferListSize = AudioBufferList.sizeInBytes(maximumBuffers: 1)
    // PCM数据描述信息，即输入音频格式
    fileprivate var inSourceFormat: AudioStreamBasicDescription? {
        didSet {
            guard let inSourceFormat = self.inSourceFormat else { return }
            let nonInterleaved = inSourceFormat.mFormatFlags & kAudioFormatFlagIsNonInterleaved != 0
            if nonInterleaved {
                maximumBuffers = Int(inSourceFormat.mChannelsPerFrame)
                bufferListSize = AudioBufferList.sizeInBytes(maximumBuffers: maximumBuffers)
            }
        }
    }
    fileprivate var inputDataProc: AudioConverterComplexInputDataProc = {(
        converter: AudioConverterRef,
        ioNumberDataPackets: UnsafeMutablePointer<UInt32>,
        ioData: UnsafeMutablePointer<AudioBufferList>,
        outDataPacketDescription: UnsafeMutablePointer<UnsafeMutablePointer<AudioStreamPacketDescription>?>?,
        inUserData: UnsafeMutableRawPointer?) in
        return unsafeBitCast(inUserData, to: AACEncoder.self).onInputDataForAudioConverter(ioNumberDataPackets: ioNumberDataPackets, ioData: ioData, outDataPacketDescription: outDataPacketDescription)
    }
    
    /// 目标转换格式，即输出音频格式
    fileprivate var _inDestinationFormat: AudioStreamBasicDescription?
    fileprivate var inDestinationFormat: AudioStreamBasicDescription {
        get {
            if self._inDestinationFormat == nil {
                self._inDestinationFormat = AudioStreamBasicDescription(
                    mSampleRate: inSourceFormat!.mSampleRate,// 采样率 44100
                    mFormatID: kAudioFormatMPEG4AAC, // 压缩编码格式MPEG4-AAC
                    mFormatFlags: UInt32(MPEG4ObjectID.aac_Main.rawValue),
                    mBytesPerPacket: 0,
                    mFramesPerPacket: 1024, // AAC一帧的大小，默认为1024Bytes
                    mBytesPerFrame: 0, //
                    mChannelsPerFrame: inSourceFormat!.mChannelsPerFrame, // 采样通道数， ipad4 is 1
                    mBitsPerChannel: 0, // 可能是采样位数
                    mReserved: 0)//  Pads the structure out to force an even 8-byte alignment. Must be set to 0.
                
                CMAudioFormatDescriptionCreate(kCFAllocatorDefault, &self._inDestinationFormat!, 0, nil, 0, nil, nil, &formatDescription) // 这个地方第一次给 formatDescription设置值。
            }
            return self._inDestinationFormat!
        }
        set {
            self._inDestinationFormat = newValue
        }
    }
    fileprivate var inClassDescriptions: [AudioClassDescription] = [
        AudioClassDescription(mType: kAudioEncoderComponentType, mSubType: kAudioFormatMPEG4AAC, mManufacturer: kAppleSoftwareAudioCodecManufacturer),
        AudioClassDescription(mType: kAudioEncoderComponentType, mSubType: kAudioFormatMPEG4AAC, mManufacturer: kAppleHardwareAudioCodecManufacturer)
    ]
    
    /// 为Audio Converter提供数据的回调
    private func onInputDataForAudioConverter(ioNumberDataPackets: UnsafeMutablePointer<UInt32>, ioData: UnsafeMutablePointer<AudioBufferList>, outDataPacketDescription:UnsafeMutablePointer<UnsafeMutablePointer<AudioStreamPacketDescription>?>?) -> OSStatus {
        guard let bufferList = currentBufferList else {
            ioNumberDataPackets.pointee = 0
            return -1
        }
        memcpy(ioData, bufferList.unsafePointer, bufferListSize)
        ioNumberDataPackets.pointee = 1
        free(bufferList.unsafeMutablePointer)
        currentBufferList = nil
        return noErr
    }
    
    fileprivate var _converter: AudioConverterRef?
    fileprivate var converter: AudioConverterRef {
        if self._converter == nil {
            var converter: AudioConverterRef? = nil
            let status = AudioConverterNewSpecific(&self.inSourceFormat!, &self.inDestinationFormat, UInt32(self.inClassDescriptions.count), &inClassDescriptions, &converter)
            if status == noErr {
                var bitrate: UInt32 = self.bitrate*self.inDestinationFormat.mChannelsPerFrame
                AudioConverterSetProperty(converter!, kAudioConverterEncodeBitRate, UInt32(MemoryLayout<UInt32>.size), &bitrate) // 设置编码输出码率 32kbps
            }
            self._converter = converter
        }
        return self._converter!
    }
    
    private func createAudioBufferList(channels: UInt32, size: UInt32) -> AudioBufferList {
        let audioBuffer = AudioBuffer(mNumberChannels: channels, mDataByteSize: size, mData: UnsafeMutableRawPointer.allocate(bytes: MemoryLayout<UInt32>.size(ofValue: size), alignedTo: MemoryLayout<UInt32>.alignment(ofValue: size)))
        return AudioBufferList(mNumberBuffers: 1, mBuffers: audioBuffer)
    }
    
    func encode(sampleBuffer: CMSampleBuffer) {
        guard isRunning, let format = CMSampleBufferGetFormatDescription(sampleBuffer) else { return }
        if inSourceFormat == nil {
            inSourceFormat = CMAudioFormatDescriptionGetStreamBasicDescription(format)?.pointee // 获取原始 PCM 信息
        }
        
        var blockBuffer: CMBlockBuffer?
        currentBufferList = AudioBufferList.allocate(maximumBuffers: maximumBuffers)
        CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(sampleBuffer, nil, currentBufferList!.unsafeMutablePointer, bufferListSize, nil, nil, 0, &blockBuffer)
        
        if muted {
            for buffer in currentBufferList! {
                memset(buffer.mData, 0, Int(buffer.mDataByteSize))
            }
        }
        
        var ioOutputDataPacketSize: UInt32 = 1
        let dataLength = CMBlockBufferGetDataLength(blockBuffer!)
        let outputData = AudioBufferList.allocate(maximumBuffers: 1)
        outputData[0].mNumberChannels = inDestinationFormat.mChannelsPerFrame
        outputData[0].mDataByteSize = UInt32(dataLength)
        outputData[0].mData = malloc(dataLength)
        
        let status = AudioConverterFillComplexBuffer(converter, inputDataProc, unsafeBitCast(self, to: UnsafeMutableRawPointer.self), &ioOutputDataPacketSize, outputData.unsafeMutablePointer, nil) // Fill this output buffer with encoded data from the encoder
        if status == noErr {
            var outputBuffer: CMSampleBuffer?
            var timing = CMSampleTimingInfo(duration: CMSampleBufferGetDuration(sampleBuffer), presentationTimeStamp: CMSampleBufferGetPresentationTimeStamp(sampleBuffer), decodeTimeStamp: CMSampleBufferGetDecodeTimeStamp(sampleBuffer))
            let numSamples = CMSampleBufferGetNumSamples(sampleBuffer)
            CMSampleBufferCreate(kCFAllocatorDefault, nil, false, nil, nil, formatDescription, numSamples, 1, &timing, 0, nil, &outputBuffer)
            CMSampleBufferSetDataBufferFromAudioBufferList(outputBuffer!, kCFAllocatorDefault, kCFAllocatorDefault, 0, outputData.unsafePointer)
            // 编码后输出的音频包
            delegate?.didGetAACSampleBuffer(outputBuffer) // 编码完成的数据
        }
        
        for buffer in outputData {
            free(buffer.mData)
        }
        free(outputData.unsafeMutablePointer)
    }
    
    func run() {
        aacEncoderQueue.async {
            self.isRunning = true
        }
    }
    
    func stop() {
        aacEncoderQueue.async {
            if self._converter != nil {
                AudioConverterDispose(self._converter!)
                self._converter = nil
            }
            self.inSourceFormat = nil
            self.formatDescription = nil
            self._inDestinationFormat = nil
            self.currentBufferList = nil
            self.isRunning = false
        }
    }
}

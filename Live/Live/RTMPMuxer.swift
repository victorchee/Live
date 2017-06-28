//
//  RTMPMuxer.swift
//  Live
//
//  Created by VictorChee on 2016/12/22.
//  Copyright © 2016年 VictorChee. All rights reserved.
//

import Foundation
import AVFoundation

protocol RTMPMuxerDelegate: class {
    func sampleOutput(audio buffer: NSData, timestamp: Double)
    func sampleOutput(video buffer: NSData, timestamp: Double)
}

class RTMPMuxer {
    fileprivate var previousDts = kCMTimeZero
    fileprivate var audioTimestamp = kCMTimeZero
    
    weak var delegate: RTMPMuxerDelegate?
    /* AVC Sequence Packet
     * @see http://www.adobe.com/content/dam/Adobe/en/devnet/flv/pdfs/video_file_format_spec_v10.pdf
     * - seealso: http://billhoo.blog.51cto.com/2337751/1557646
     * @see # VIDEODATA
     * AVC Sequence Header:
     * 1. FrameType(high 4bits), should be keyframe(type id = 1)
     * 2. CodecID(low 4bits), should be AVC(type id = 7)
     * @see # AVCVIDEOPACKET
     * 3. AVCVIDEOPACKET:
     *     1.) AVCPacketType(8bits), should be AVC sequence header(type id = 0)
     *     2.) COmposotion Time(24bits), should be 0
     *     3.) AVCDecoderConfigurationRecord(n bits)
     */
    private func createAVCSequenceHeader(formatDescription: CMFormatDescription) -> NSData? {
        var buffer = Data()
        var data = [UInt8](repeating: 0x00, count: 5)
        // FrameType(4bits) | CodecID(4bits)
        data[0] = FLVFrameType.key.rawValue << 4 | FLVVideoCodec.avc.rawValue
        // AVCPacketType(8bits)
        data[1] = FLVAVCPacketType.seq.rawValue
        // COmposotion Time(24bits)
        data[2...4] = [0x00, 0x00, 0x00]
        buffer.append(&data, count: data.count)
        // AVCDecoderConfigurationRecord Packet
        guard let atoms = CMFormatDescriptionGetExtension(formatDescription, "SampleDescriptionExtensionAtoms" as CFString) else { return nil }
        guard let AVCDecoderConfigurationRecordPacket = atoms["avcC"] as? Data else { return nil }
        buffer.append(AVCDecoderConfigurationRecordPacket)
        return buffer as NSData
    }
    
    func muxAVCFormatDescription(formatDescription: CMFormatDescription?) {
        guard let formatDescription = formatDescription else { return }
        guard let AVCSequenceHeader = createAVCSequenceHeader(formatDescription: formatDescription) else { return }
        delegate?.sampleOutput(video: AVCSequenceHeader, timestamp: 0)
    }
    
    /// 视频数据包
    func muxAVCSampleBuffer(sampleBuffer: CMSampleBuffer) {
        guard let block = CMSampleBufferGetDataBuffer(sampleBuffer) else { return }
        let isKeyFrame = !CFDictionaryContainsKey(unsafeBitCast(CFArrayGetValueAtIndex(CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, true), 0), to: CFDictionary.self), unsafeBitCast(kCMSampleAttachmentKey_NotSync, to: UnsafeRawPointer.self))
        // 判断当前帧是否为关键帧 获取sps & pps 数据
        // 解析出参数集SPS和PPS，加上开始码后组装成NALU。提取出视频数据，将长度码转换成开始码，组长成NALU。将NALU发送出去。
        var totalLength: Int = 0
        var dataPointer: UnsafeMutablePointer<Int8>? = nil
        CMBlockBufferGetDataPointer(block, 0, nil, &totalLength, &dataPointer)
        var cto: Int32 = 0
        let pts = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        var dts = CMSampleBufferGetDecodeTimeStamp(sampleBuffer)
        
        if dts == kCMTimeInvalid {
            dts = pts
        } else {
            cto = Int32((CMTimeGetSeconds(pts)-CMTimeGetSeconds(dts))*1000)
        }
        
        let timeDelta = (self.previousDts == kCMTimeZero ? 0 : CMTimeGetSeconds(dts)-CMTimeGetSeconds(self.previousDts)) * 1000
        let buffer = NSMutableData()
        var data = [UInt8](repeating: 0x00, count: 5)
        // FrameType(4bits) | CodecID(4bits)
        data[0] = ((isKeyFrame ? UInt8(0x01) : UInt8(0x02)) << 4) | UInt8(0x07)
        // AVCPacketType(8bits)
        data[1] = UInt8(0x01)
        // COmposotion Time(24bits)
        data[2...4] = cto.bigEndian.bytes[1...3]
        buffer.append(&data, length: data.count)
        // H264 NALU Size + NALU Raw Data
        buffer.append(dataPointer!, length: totalLength)
        delegate?.sampleOutput(video: buffer, timestamp: timeDelta)
        previousDts = dts
    }
    
    /// 音频数据包
    func muxAACSampleBuffer(sampleBuffer: CMSampleBuffer?) {
        guard let sampleBuffer = sampleBuffer else { return }
        var block: CMBlockBuffer?
        var audioBufferList = AudioBufferList()
        CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(sampleBuffer, nil, &audioBufferList, MemoryLayout<AudioBufferList>.size, nil, nil, 0, &block)
        let presentationTimestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        let delta = (audioTimestamp==kCMTimeZero ? 0 : CMTimeGetSeconds(presentationTimestamp)-CMTimeGetSeconds(audioTimestamp)) * 1000
        guard let _ = block, 0 <= delta else { return }
        
        let buffer = NSMutableData()
        
        var data: [UInt8] = [0x00, FLVAACPacketType.raw.rawValue]
        data[0] = FLVAudioCodec.aac.rawValue << 4 | FLVSoundRate.kHz44.rawValue << 2 | FLVSoundSize.snd16bit.rawValue << 1 | FLVSoundType.stereo.rawValue
        buffer.append(&data, length: data.count)
        
        buffer.append(audioBufferList.mBuffers.mData!, length: Int(audioBufferList.mBuffers.mDataByteSize))
        delegate?.sampleOutput(audio: buffer, timestamp: delta)
        audioTimestamp = presentationTimestamp
    }
    
    /// 音频同步包
    func muxAACFormatDescription(formatDescription: CMFormatDescription?) {
        guard let formatDescription = formatDescription else { return }
        let buffer = NSMutableData()
        let configuration = AudioSpecificConfiguration(formatDescription: formatDescription).bytes
        // 第 1 个字节高 4 位 |0b1010| 代表音频数据编码类型为 AAC，接下来 2 位 |0b11| 表示采样率为 44kHz，接下来 1 位 |0b1| 表示采样点位数 16bit，最低 1 位 |0b1| 表示双声道
        // data的第二个字节为0，0 则为 AAC 音频同步包，1 则为普通 AAC 数据包
        var data: [UInt8] = [0x00, 0x00]
        // 音频同步包的头的第一个字节
        data[0] = FLVAudioCodec.aac.rawValue << 4 | FLVSoundRate.kHz44.rawValue << 2 | FLVSoundSize.snd16bit.rawValue << 1 | FLVSoundType.stereo.rawValue
        data[1] = FLVAACPacketType.seq.rawValue
        buffer.append(&data, length: data.count)
        buffer.append(configuration, length: configuration.count)
        delegate?.sampleOutput(audio: buffer, timestamp: 0)
    }
}

extension ExpressibleByIntegerLiteral {
    var bytes: [UInt8] {
        var value = self
        return withUnsafeBytes(of: &value) { Array($0) }
    }
    
    init(bytes: [UInt8]) {
        self = bytes.withUnsafeBytes { $0.baseAddress!.load(as: Self.self)}
    }
}

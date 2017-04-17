//
//  RTMPPublicClient.swift
//  RTMP
//
//  Created by VictorChee on 2016/12/22.
//  Copyright © 2016年 VictorChee. All rights reserved.
//

import Foundation

@objc public protocol RTMPPublisherDelegate {
    @objc optional func publishStreamHasDone()
}

open class RTMPPublishClient {
    fileprivate var socket: RTMPSocket!
    fileprivate var publisherQueue = DispatchQueue(label: "RTMPPublishClient")
    fileprivate var mediaMetaData: [String: Any]!
    fileprivate var stream: RTMPStream?
    
    weak open var delegate: RTMPPublisherDelegate?
    
    public init() { }
    
    public init(rtmpUrl: String) {
        rtmpSocketInit(rtmpUrl: rtmpUrl)
    }
    
    open func connect(rtmpUrl: String) {
        rtmpSocketInit(rtmpUrl: rtmpUrl)
        connect()
    }
    
    private func rtmpSocketInit(rtmpUrl: String) {
        guard let url = URL(string: rtmpUrl) else { return }
        socket = RTMPSocket(rtmpURL: url)
    }
    
    /**
        整个RTMP连接过程分为3步：
        1. Connect
        2. Create Stream
        3. Publishing Content
    */
    open func connect() {
        publisherQueue.async {
            self.socket.connect()
            
            // RTMP simple handshake
            let handshake = RTMPHandshake(socket: self.socket)
            handshake.shakeSimpleHand()
            
            // RTMP connect
            let connector = RTMPConnector(socket: self.socket)
            connector.connectApp()
            
            // RTMP create stream
            connector.createStream()
            
            // RTMP publish stream
            self.stream = RTMPStream(socket: self.socket)
            self.stream?.publishStream()
            self.stream?.setMetaData(self.mediaMetaData)
            self.delegate?.publishStreamHasDone?()
            
            // 当以上工作都完成的时候，就可以发送音视频了。音视频RTMP消息的Payload中都放的是按照FLV-TAG格式封的音视频包
        }
    }
    
    open func setMediaMetaData(_ metaData: [String: Any]) {
        if mediaMetaData == nil {
            mediaMetaData = [String: Any]()
        }
        
        for key in metaData.keys {
            mediaMetaData[key] = metaData[key]
        }
    }
    
    open func publishVideo(_ videoBuffer: [UInt8], timestamp: UInt32) {
        guard let stream = self.stream else { return }
        stream.publishVideo(videoBuffer, timestamp: timestamp)
    }
    
    open func publishAudio(_ audioBuffer: [UInt8], timestamp: UInt32) {
        guard let stream = self.stream else { return }
        stream.publishAudio(audioBuffer, timestamp: timestamp)
    }
    
    open func stop() {
        publisherQueue.async {
            if let stream = self.stream {
                stream.FCUnpublish()
                stream.deleteStream()
            }
            self.socket.disconnect()
        }
    }
}

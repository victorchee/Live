//
//  RTMPMessage.swift
//  RTMP
//
//  Created by Migu on 2016/12/21.
//  Copyright © 2016年 VictorChee. All rights reserved.
//

import Foundation

enum MessageType: UInt8 {
    case SetChunkSize     = 0x01
    case Abort            = 0x02
    case Acknowledgement  = 0x03
    case UserControl      = 0x04
    case WindowAckSize    = 0x05
    case SetPeerBandwidth = 0x06
    case Audio            = 0x08
    case Video            = 0x09
    case AMF3Data         = 0x0f
    case AMF3SharedObject = 0x10
    case AMF3Command      = 0x11
    case AMF0Data         = 0x12
    case AMF0SharedObject = 0x13
    case AMF0Command      = 0x14
    case Aggregate        = 0x16
    case Unknown          = 0xff
}

class RTMPMessage {
    /**
     0 1 2 3
     0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
     +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
     | Message Type  | Payload length                                |
     | (1 byte)      | (3 bytes)                                     |
     +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
     | Timestamp                                                     |
     | (4 bytes)                                                     |
     +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
     | Stream ID                                     |
     | (3 bytes)                                     |
     +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
     Message Header
     */
    
    /// 1B message type
    var messageType: MessageType!
    /// 3B message payload length
    var payloadLength: Int {
        get { return payload.count }
        set { }
    }
    /// RTMP的时间戳在发送音视频之前都为零，开始发送音视频消息的时候只要保证时间戳是单增的基本就可以正常播放音视频
    /// 4B timestamp
    var timestamp: UInt32 = 0
    /// 4B stream id
    var messageStreamID: UInt32 = 0
    /// Message payload
    var payload = [UInt8]()
    
    // Empty initialize for subclass to override
    init() {}
    
    init(messageType: MessageType) {
        self.messageType = messageType
    }
    
    class func create(messageType: MessageType) -> RTMPMessage? {
        switch messageType {
        case .SetChunkSize:
            return RTMPSetChunkSizeMessage()
        case .Abort:
            return RTMPAbortMessage()
        case .UserControl:
            return nil
        case .WindowAckSize:
            return RTMPWindowAckSizeMessage()
        case .SetPeerBandwidth:
            return RTMPSetPeerBandwidthMessage()
        case .Audio:
            return RTMPAudioMessage()
        case .Video:
            return RTMPVideoMessage()
        case .AMF0Command:
            return RTMPCommandMessage()
        case .AMF0Data:
            return RTMPDataMessage()
        case .Acknowledgement:
            return RTMPAcknowledgementMessage()
        default:
            return nil
        }
    }
}

final class RTMPSetChunkSizeMessage: RTMPMessage {
    var chunkSize = 0
    
    override init() {
        super.init(messageType: .SetChunkSize)
    }
    
    init(chunkSize: Int) {
        super.init(messageType: .SetChunkSize)
        self.chunkSize = chunkSize
    }
    
    override var payload: [UInt8] {
        get {
            guard super.payload.isEmpty else {
                return super.payload
            }
            super.payload += Int32(chunkSize).bigEndian.bytes
            return super.payload
        }
        set {
            chunkSize = Int(Int32(bytes: newValue).bigEndian)
        }
    }
}

final class RTMPAbortMessage: RTMPMessage {
    private var chunkStreamID: Int32!
    
    override init() {
        super.init(messageType: .Abort)
    }
    
    init(chunkStreamID: Int32) {
        super.init(messageType: .Abort)
        self.chunkStreamID = chunkStreamID
    }
    
    override var payload: [UInt8] {
        get {
            guard super.payload.isEmpty else {
                return super.payload
            }
            super.payload += chunkStreamID.bigEndian.bytes
            return super.payload
        }
        set {
            chunkStreamID = Int32(bytes: newValue).bigEndian
        }
    }
}

final class RTMPAcknowledgementMessage: RTMPMessage {
    var sequence: Int32!
    
    override init() {
        super.init(messageType: .Acknowledgement)
    }
    
    init(sequence: Int32) {
        super.init(messageType: .Acknowledgement)
        self.sequence = sequence
    }
    
    override var payload: [UInt8] {
        get {
            guard super.payload.isEmpty else {
                return super.payload
            }
            super.payload += sequence.bigEndian.bytes
            return super.payload
        }
        set {
            sequence = Int32(bytes: newValue).bigEndian
        }
    }
}

final class RTMPWindowAckSizeMessage: RTMPMessage {
    var windowAckSize: UInt32!
    
    override init() {
        super.init(messageType: .WindowAckSize)
    }
    
    init(windowAckSize: UInt32) {
        super.init(messageType: .WindowAckSize)
        self.windowAckSize = windowAckSize
        self.timestamp = 0
    }
    
    override var payload: [UInt8] {
        get {
            guard super.payload.isEmpty else {
                return super.payload
            }
            super.payload += windowAckSize.bigEndian.bytes
            return super.payload
        }
        set {
            windowAckSize = UInt32(bytes: newValue).bigEndian
        }
    }
}

final class RTMPSetPeerBandwidthMessage: RTMPMessage {
    enum LimitType: UInt8 {
        case Hard = 0x00
        case Soft = 0x01
        case Dynamic = 0x02
        case Unknown = 0xFF
    }
    
    var ackWindowSize: UInt32 = 0
    var limit = LimitType.Hard
    
    override init() {
        super.init(messageType: .SetPeerBandwidth)
    }
    
    init(ackWindowSize: UInt32, limitType: LimitType, messageStreamID: UInt32) {
        super.init(messageType: .SetPeerBandwidth)
        self.ackWindowSize = ackWindowSize
        self.messageStreamID = messageStreamID
    }
    
    override var payload: [UInt8] {
        get {
            guard super.payload.isEmpty else {
                return super.payload
            }
            super.payload += ackWindowSize.bigEndian.bytes
            super.payload += [limit.rawValue]
            return super.payload
        }
        set {
            if super.payload == newValue { return }
            self.ackWindowSize = UInt32(bytes: Array(newValue[0...3])).bigEndian
            self.limit = LimitType(rawValue: newValue[4])!
        }
    }
}

/// Command Message(命令消息，Message Type ID＝17或20)：表示在客户端盒服务器间传递的在对端执行某些操作的命令消息，如connect表示连接对端，对端如果同意连接的话会记录发送端信息并返回连接成功消息，publish表示开始向对方推流，接受端接到命令后准备好接受对端发送的流信息，后面会对比较常见的Command Message具体介绍。当信息使用AMF0编码时，Message Type ID＝20，AMF3编码时Message Type ID＝17.
final class RTMPCommandMessage: RTMPMessage {
    var commandName = ""
    /// 用来标识command类型的消息的，服务器返回的_result消息可以通过这个来区分是对哪个命令的回应
    var transactionID = 0
    var commandObjects = [Amf0Data]()
    
    override init() {
        super.init(messageType: .AMF0Command)
    }
    
    init(commandName: String, transactionID: Int, messageStreamID: UInt32) {
        super.init(messageType: .AMF0Command)
        self.commandName = commandName
        self.transactionID = transactionID
        self.messageStreamID = messageStreamID
    }
    
    override var payload: [UInt8] {
        get {
            guard super.payload.isEmpty else {
                return super.payload
            }
            super.payload += Amf0String(value: commandName).dataInBytes
            super.payload += Amf0Number(value: transactionID).dataInBytes
            for object in commandObjects {
                super.payload += object.dataInBytes
            }
            return super.payload
        }
        set {
            let inputStream = ByteArrayInputStream(byteArray: newValue)
            guard let commandName = Amf0String.decode(inputStream, isAmfObjectKey: false) else {
                return
            }
            self.commandName = commandName
            self.transactionID = Int(Amf0Number.decode(inputStream))
            while inputStream.remainLength > 0 {
                guard let object = Amf0Data.create(inputStream) else { return }
                commandObjects.append(object)
            }
        }
    }
}

/// Data Message（数据消息，Message Type ID＝15或18）：传递一些元数据（MetaData，比如视频名，分辨率等等）或者用户自定义的一些消息。当信息使用AMF0编码时，Message Type ID＝18，AMF3编码时Message Type ID＝15.
final class RTMPDataMessage: RTMPMessage {
    private var type: String!
    var objects = [Amf0Data]()
    
    override init() {
        super.init(messageType: .AMF0Data)
    }
    
    init(type: String, messageStreamID: UInt32) {
        super.init(messageType: .AMF0Data)
        self.type = type
        self.messageStreamID = messageStreamID
    }
    
    override var payload: [UInt8] {
        get {
            guard super.payload.isEmpty else {
                return super.payload
            }
            super.payload += Amf0String(value: type).dataInBytes
            for object in objects {
                super.payload += object.dataInBytes
            }
            return super.payload
        }
        set {
            let inputStream = ByteArrayInputStream(byteArray: newValue)
            guard let type = Amf0String.decode(inputStream, isAmfObjectKey: false) else {
                return
            }
            self.type = type
            while inputStream.remainLength > 0 {
                guard let object = Amf0Data.create(inputStream) else { return }
                objects.append(object)
            }
        }
    }
}

/// Audio Message（音频信息，Message Type ID＝8）：音频数据。
final class RTMPAudioMessage: RTMPMessage {
    override init() {
        super.init(messageType: .Audio)
    }
    
    init(audioBuffer: [UInt8], messageStreamID: UInt32) {
        super.init(messageType: .Audio)
        self.messageStreamID = messageStreamID
        self.payload = audioBuffer
    }
    
    override var payload: [UInt8] {
        get { return super.payload }
        set {
            guard super.payload != newValue else { return }
            super.payload = newValue
        }
    }
}

/// Video Message（视频信息，Message Type ID＝9）：视频数据。
final class RTMPVideoMessage: RTMPMessage {
    override init() {
        super.init(messageType: .Video)
    }
    
    init(videoBuffer: [UInt8], messageStreamID: UInt32) {
        super.init(messageType: .Video)
        self.messageStreamID = messageStreamID
        self.payload = videoBuffer
    }
    
    override var payload: [UInt8] {
        get { return super.payload }
        set {
            guard super.payload != newValue else { return }
            super.payload = newValue
        }
    }
}

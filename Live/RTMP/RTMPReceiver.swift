//
//  RTMPReceiver.swift
//  RTMP
//
//  Created by Migu on 2016/12/22.
//  Copyright © 2016年 VictorChee. All rights reserved.
//

import Foundation

class RTMPReceiver {
    private let socket: RTMPSocket
    /// Key: chunk stream id, Value: chunk
    private var chunkStreams: [UInt16: RTMPChunk]!
    
    init(socket: RTMPSocket) {
        self.socket = socket
        self.chunkStreams = [UInt16: RTMPChunk]()
    }
    
    final func readInterlacedMessage() -> RTMPMessage? {
        // Basic header fmt
        var fmt: UInt8 = 0
        var chunkStreamID: UInt16 = 0
        // Current chunk info
        var chunk: RTMPChunk!
        // Current message payload length
        var payloadLength: Int!
        // Message payload has read
        var payloadBuffer = [UInt8]()
        
        func readBasicHeader() {
            // 1B chunk basic header
            let basicHeader = socket.read()
            
            // 2b fmt
            fmt = (basicHeader >> 6) & 0x03
            chunkStreamID = UInt16(basicHeader & 0x3f) // 2~7b
            
            // 2-63, 1B chunk header
            if chunkStreamID > 1 { return }
            
            // 64-319, 2B chunk header
            if chunkStreamID == 0 {
                chunkStreamID = UInt16(socket.read()) + 64 // second byte + 64
            } else if chunkStreamID == 1 {
                // 64-65599, 3B chunk header
                var idInBytes = [UInt8](repeating: 0x00, count: 2)
                socket.read(&idInBytes, maxLength: 2)
                chunkStreamID = UInt16((idInBytes[1] << 8) | idInBytes[0]) + 64 // third byte * 256 + second byte + 64
            } else {
                // error
            }
        }
        
        func readMessageHeader() {
            // Find the previous chunk info
            chunk = chunkStreams[chunkStreamID]
            if chunk == nil {
                // Don't hava previous chunk, it's the first chunk
                chunk = RTMPChunk()
                chunkStreams[chunkStreamID] = chunk
            }
            
            let isFirstChunk = payloadLength == nil
            if isFirstChunk && fmt != 0x00 {
                if chunkStreamID == RTMPChunk.ControlChannel && fmt == 0x01 {
                    // TAG, accept cid=2, fmt=1 to make librtmp happy
                } else {
                    // RTMP protocol level error
                }
            }
            
            var hasExtendedTimestamp = false
            var timestampDelta: UInt32!
            if fmt <= 0x02 {
                // Zero / One / Two
                timestampDelta = UInt32(bytes: [0x00] + socket.read3Bytes()).bigEndian
                hasExtendedTimestamp = timestampDelta >= 0xffffff
                if !hasExtendedTimestamp {
                    if fmt == 0x00 {
                        // Zero
                        chunk.timestamp = timestampDelta
                    } else {
                        // One / Two
                        chunk.timestamp = chunk.timestamp! + timestampDelta
                    }
                }
                
                if fmt <= 0x01 {
                    // Zero / One
                    payloadLength = Int(Int32(bytes: [0x00] + socket.read3Bytes()).bigEndian)
                    chunk.messageType = MessageType(rawValue: socket.read())
                    if fmt == 0x00 {
                        // Zero
                        var bytes = [UInt8](repeating: 0x00, count: 4)
                        socket.read(&bytes, maxLength: 4)
                        chunk.messageStreamID = UInt32(bytes: bytes)
                    } else {
                        // Read complete
                    }
                }
            } else {
                // Three
                if isFirstChunk && !hasExtendedTimestamp {
                    chunk.timestamp = chunk.timestamp! + timestampDelta
                }
            }
            
            if hasExtendedTimestamp {
                var bytes = [UInt8](repeating: 0x00, count: 4)
                socket.read(&bytes, maxLength: 4)
                chunk.timestamp = UInt32(bytes: bytes).bigEndian
            }
        }
        
        func readMessagePayload() {
            var size = payloadLength - payloadBuffer.count
            size = min(size, socket.inChunkSize)
            var bytes = [UInt8](repeating: 0x00, count: size)
            socket.read(&bytes, maxLength: size)
            payloadBuffer += bytes
        }
        
        // Start read chunk until get a complete message
        while true {
            readBasicHeader()
            readMessageHeader()
            readMessagePayload()
            
            if payloadLength <= 0 {
                // Get an empty message
                return nil
            }
            
            // Get complete message
            if payloadLength == payloadBuffer.count {
                guard let message = RTMPMessage.create(messageType: chunk.messageType) else {
                    // Create message error
                    return nil
                }
                message.payloadLength = payloadLength
                message.timestamp = chunk.timestamp
                message.messageStreamID = chunk.messageStreamID
                message.payload = payloadBuffer
                return message
            }
        }
    }
    
    func receiveMessage() -> RTMPMessage? {
        guard let message = readInterlacedMessage() else { return nil }
        handleReceivedMessage(message)
        return message
    }
    
    func handleReceivedMessage(_ message: RTMPMessage) {
        // TODO: send ack when total byte > 25000000
        switch message.messageType! {
        case .WindowAckSize:
            guard let message = message as? RTMPWindowAckSizeMessage else { return }
            RTMPChunk.inWindowAckSize = message.windowAckSize
        case .SetChunkSize:
            guard let message = message as? RTMPSetChunkSizeMessage else { return }
            socket.inChunkSize = message.chunkSize
        default:
            // TODO: user control 
            break
        }
    }
    
    func expectCommandMessage(transactionID: Int) -> RTMPCommandMessage? {
        while true {
            guard let message = receiveMessage() as? RTMPCommandMessage else { continue }
            
            let commandName = message.commandName
            // _result消息表示接受该命令，对端可以继续往下执行流程
            // _error消息代表拒绝该命令要执行的操作
            // method name消息代表要在之前命令的发送端执行的函数名称
            if commandName == "_result" || commandName == "_error" {
                if transactionID == message.transactionID {
                    return message
                } else {
                    // Drop unexpect message
                }
            } else {
                // Drop unexpect message
            }
        }
    }
}

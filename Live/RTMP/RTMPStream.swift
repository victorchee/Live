//
//  RTMPStream.swift
//  RTMP
//
//  Created by Migu on 2016/12/22.
//  Copyright © 2016年 VictorChee. All rights reserved.
//

import Foundation

class RTMPStream {
    var socket: RTMPSocket!
    static var messageStreamID: UInt32 = 0
    var isFirstVideoMessage = true
    var isFirstAudioMessage = true
    
    init(socket: RTMPSocket) {
        self.socket = socket
    }
    
    /// 推流准备工作的最后一步是Publish Stream，即向服务器发一个publish命令，这个命令的message stream ID就是上一步create stream之后服务器返回的stream ID，发完这个命令一般不用等待服务器返回的回应，直接下一步发送音视频数据。有些rtmp库 还会发setMetaData消息，这个消息可以发也可以不发，里面包含了一些音视频编码的信息
    func publishStream() {
        let commandMessage = RTMPCommandMessage(commandName: "publish", transactionID: 0x05, messageStreamID: RTMPStream.messageStreamID)
        commandMessage.commandObjects.append(Amf0Null())
        commandMessage.commandObjects.append(Amf0String(value: socket.stream))
        commandMessage.commandObjects.append(Amf0String(value: socket.app))
        
        socket.write(message: commandMessage, chunkType: .Type0, chunkStreamID: 0x08)
    }
    
    func setMetaData(_ metaData: [String: Any]) {
        let dataMessage = RTMPDataMessage(type: "@setDataFrame", messageStreamID: RTMPStream.messageStreamID)
        dataMessage.objects.append(Amf0String(value: "onMetaData"))
        let ecmaArray = Amf0Map()
        for key in metaData.keys {
            ecmaArray.setProperties(key: key, value: metaData[key] as Any)
        }
        dataMessage.objects.append(ecmaArray)
        
        socket.write(message: dataMessage, chunkType: .Type0, chunkStreamID: 0x04)
    }
    
    func FCUnpublish() {
        let commandMessage = RTMPCommandMessage(commandName: "FCUnpublish", transactionID: 0x06, messageStreamID: RTMPStream.messageStreamID)
        commandMessage.commandObjects.append(Amf0Null())
        commandMessage.commandObjects.append(Amf0String(value: socket.stream))
        
        socket.write(message: commandMessage, chunkType: .Type1, chunkStreamID: 0x03)
    }
    
    func deleteStream() {
        let commandMessage = RTMPCommandMessage(commandName: "deleteStream", transactionID: 0x07, messageStreamID: RTMPStream.messageStreamID)
        commandMessage.commandObjects.append(Amf0Null())
        commandMessage.commandObjects.append(Amf0Number(value: RTMPStream.messageStreamID))
        
        socket.write(message: commandMessage, chunkType: .Type1, chunkStreamID: 0x03)
    }
    
    func publishVideo(_ videoBuffer: [UInt8], timestamp: UInt32) {
        let videoMessage = RTMPVideoMessage(videoBuffer: videoBuffer, messageStreamID: RTMPStream.messageStreamID)
        videoMessage.timestamp = timestamp
        
        let chunkType = isFirstVideoMessage ? ChunkType.Type0 : .Type1
        
        socket.write(message: videoMessage, chunkType: chunkType, chunkStreamID: RTMPChunk.VideoChannel)
        isFirstVideoMessage = false
    }
    
    func publishAudio(_ audioBuffer: [UInt8], timestamp: UInt32) {
        let audioMessage = RTMPAudioMessage(audioBuffer: audioBuffer, messageStreamID: RTMPStream.messageStreamID)
        audioMessage.timestamp = timestamp
        
        let chunkType = isFirstAudioMessage ? ChunkType.Type0 : .Type1
        
        socket.write(message: audioMessage, chunkType: chunkType, chunkStreamID: RTMPChunk.AudioChannel)
        isFirstAudioMessage = false
    }
}

//
//  RTMPConnector.swift
//  RTMP
//
//  Created by Migu on 2016/12/22.
//  Copyright © 2016年 VictorChee. All rights reserved.
//

import Foundation

class RTMPConnector {
    var socket: RTMPSocket!
    var messageReceiver: RTMPReceiver!
    
    init(socket: RTMPSocket) {
        self.socket = socket
        self.messageReceiver = RTMPReceiver(socket: socket)
    }
    
    /// 握手之后先发送一个AMF格式的connect命令消息
    func connectApp() {
        // connect命令的事务ID必须为1
        let command = RTMPCommandMessage(commandName: "connect", transactionID: 0x01, messageStreamID: 0x00)
        let object = Amf0Object()
        object.setProperties(key: "app", value: socket.app)
        object.setProperties(key: "flashVer", value: "FMLE/3.0 (compatible; FMSc/1.0)")
        object.setProperties(key: "swfUrl", value: "")
        object.setProperties(key: "tcUrl", value: socket.hostname+"/"+socket.app)
        object.setProperties(key: "fpad", value: false);
        object.setProperties(key: "capabilities", value: 239);
        object.setProperties(key: "audioCodecs", value: 3575);
        object.setProperties(key: "pageUrl", value: "");
        object.setProperties(key: "objectEncoding", value: 0);
        // 音视频编码信息不能少
        object.setProperties(key: "videoCodecs", value: 252);
        object.setProperties(key: "videoFunction", value: 1);
        command.commandObjects.append(object)
        
        socket.write(message: command, chunkType: RTMPChunk.ChunkType.zero, chunkStreamID: RTMPChunk.CommandChannel)
        
        // 发送完connect命令之后一般会发一个set chunk size消息来设置chunk size的大小，也可以不发
        // Set client out chunk size 1024*8
        socket.outChunkSize = 1024 * 8
        let setChunkSize = RTMPSetChunkSizeMessage(chunkSize: socket.outChunkSize)
        socket.write(message: setChunkSize, chunkType: RTMPChunk.ChunkType.zero, chunkStreamID: RTMPChunk.ControlChannel)
        
        if let message = messageReceiver.expectCommandMessage(transactionID: 0x01) {
            if message.commandName == "_result" {
                print("App connect success")
            } else if message.commandName == "_error" {
                print("App connect refused")
            }
        }
    }
    
    /// 创建RTMP流
    /// 客户端要向服务器发送一个releaseStream命令消息，之后是FCPublish命令消息，在之后是createStream命令消息。当发送完createStream消息之后，解析服务器返回的消息会得到一个stream ID, 这个ID也就是以后和服务器通信的 message stream ID, 一般返回的是1，不固定
    func createStream() {
        let releaseStream = RTMPCommandMessage(commandName: "releaseStream", transactionID: 0x02, messageStreamID: 0)
        releaseStream.commandObjects.append(Amf0Null())
        releaseStream.commandObjects.append(Amf0String(value: socket.stream))
        socket.write(message: releaseStream, chunkType: RTMPChunk.ChunkType.one, chunkStreamID: RTMPChunk.CommandChannel)
        
        let FCPublish = RTMPCommandMessage(commandName: "FCPublish", transactionID: 0x03, messageStreamID: 0)
        FCPublish.timestamp = 0
        FCPublish.commandObjects.append(Amf0Null())
        FCPublish.commandObjects.append(Amf0String(value: socket.stream))
        socket.write(message: FCPublish, chunkType: RTMPChunk.ChunkType.one, chunkStreamID: RTMPChunk.CommandChannel)
        
        let createStream = RTMPCommandMessage(commandName: "createStream", transactionID: 0x04, messageStreamID: 0)
        createStream.timestamp = 0
        createStream.commandObjects.append(Amf0Null())
        socket.write(message: createStream, chunkType: RTMPChunk.ChunkType.one, chunkStreamID: RTMPChunk.CommandChannel)
        
        guard let result = messageReceiver.expectCommandMessage(transactionID: 0x04) else {
            // Error
            return
        }
        
        guard let amf0Number = result.commandObjects[1] as? Amf0Number else {
            // Error
            return
        }
        
        RTMPStream.messageStreamID = UInt32(amf0Number.value)
        
        print("Create stream success")
    }
}

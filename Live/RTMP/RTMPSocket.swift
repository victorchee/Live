//
//  RTMPSocket.swift
//  RTMP
//
//  Created by Migu on 2016/12/21.
//  Copyright © 2016年 VictorChee. All rights reserved.
//

import UIKit

/// RTMP的底层，RTMP的握手，收发底层字节数据，ack状态相应等
final class RTMPSocket: NSObject {
    private let rtmpSocketQueue = DispatchQueue(label: "RTMPSocketQueue")
    private var runloop: RunLoop?
    private var isServerConnected = false
    
    var totalInputBytes = 0
    /// 所有通过TCP流的输出字节
    var totalOutputBytes = 0
    
    /// RTMP是按照chunk size进行分块，chunk size指的是 chunk的payload部分的大小，不包括chunk basic header 和 chunk message header，即chunk的body的大小。
    /// 客户端和服务器端各自维护了两个chunk size, 分别是自身分块的chunk size 和 对端 的chunk size, 默认的这两个chunk size都是128字节。通过向对端发送set chunk size 消息告知对方更改了 chunk size的大小，即告诉对端：我接下来要以xxx个字节拆分RTMP消息，你在接收到消息的时候就按照新的chunk size 来组包。
    /// 在实际写代码的时候一般会把chunk size设置的很大，有的会设置为4096，FFMPEG推流的时候设置的是 60*1000，这样设置的好处是避免了频繁的拆包组包，占用过多的CPU。设置太大的话也不好，一个很大的包如果发错了，或者丢失了，播放端就会出现长时间的花屏或者黑屏等现象。
    var inChunkSize = 128
    var outChunkSize = 128
    
    /// 读
    private var inputStream: InputStream?
    /// 写
    private var outputStream: OutputStream?
    
    private var port: Int!
    var hostname: String!
    var app: String!
    var stream: String!
    var rtmpURL: URL!
    
    init(rtmpURL: URL) {
        self.rtmpURL = rtmpURL
    }
    
    private func parseRTMPURL() {
        // rtmp://192.168.1.10:1935/rtmp/livestream
        // schema://host:port/app/stream

        hostname = rtmpURL.host!
        port = rtmpURL.port ?? 1935
        
        /// Rtmp app
        let components = rtmpURL.pathComponents
        app = components[1]
        
        stream = rtmpURL.lastPathComponent
    }
    
    func connect() {
        parseRTMPURL()
        
        Stream.getStreamsToHost(withName: hostname, port: port, inputStream: &inputStream, outputStream: &outputStream)
        
        guard let output = outputStream, let input = inputStream else {
            return
        }
        totalInputBytes = 0
        totalOutputBytes = 0
        input.delegate = self
        input.open()
        output.delegate = self
        output.open()
    }
    
    func disconnect() {
        rtmpSocketQueue.async {
            self.inputStream?.close()
            self.outputStream?.close()
            
            self.inputStream = nil
            self.outputStream = nil
            
            /// Reset RTMP info value
            //RTMPStream.messageStreamID = 0
            
            self.inChunkSize = 128
            self.outChunkSize = 128
        }
    }
    
    func write(message: RTMPMessage, chunkType: ChunkMessageHeaderType, chunkStreamID: UInt16) {
        guard let chunkBuffer = RTMPChunk.splitMessage(message, chunkSize: outChunkSize, chunkType: chunkType, chunkStreamID: chunkStreamID) else { return }
        self.write(bytes: chunkBuffer)
    }
    
    func write(data: Data) {
        rtmpSocketQueue.async {
            data.withUnsafeBytes {
                self.write(buffer: UnsafePointer<UInt8>($0), bufferLength: data.count)
            }
        }
    }
    
    func write(bytes: [UInt8]) {
        rtmpSocketQueue.async {
            self.write(buffer: UnsafePointer(bytes), bufferLength: bytes.count)
        }
    }
    
    private func write(buffer: UnsafePointer<UInt8>, bufferLength: Int) {
        var writeBytesCount = 0
        while true {
            guard let outputStream = self.outputStream else { return }
            let writeLength = outputStream.write(buffer.advanced(by: writeBytesCount), maxLength: bufferLength - writeBytesCount)
            if writeLength < 0 {
                // Data write error
                break
            }
            writeBytesCount += writeLength
            totalOutputBytes += writeLength
            print("socket has write \(totalOutputBytes) bytes")
            
            if bufferLength == writeBytesCount { break }
        }
    }
    
    func read3Bytes() -> [UInt8] {
        var buffer = [UInt8](repeating: 0x00, count: 3)
        self.read(&buffer, maxLength: buffer.count)
        return buffer
    }
    
    func read() -> UInt8 {
        var buffer = [UInt8](repeating: 0x00, count: 1)
        self.read(&buffer, maxLength: buffer.count)
        return buffer[0]
    }
    
    func read(_ buffer: inout [UInt8], maxLength: Int) {
        var readBytesCount = 0
        while true {
            guard let inputStream = self.inputStream else { return }
            if inputStream.hasBytesAvailable {
                let readLength = inputStream.read(&buffer, maxLength: maxLength)
                if readLength < 0 {
                    // Read error
                    break
                }
                readBytesCount += readLength
                totalInputBytes += readLength
                print("socket has read \(totalInputBytes) bytes")
                
                if readBytesCount == maxLength { break }
            }
        }
    }
}

extension RTMPSocket: StreamDelegate {
    func stream(_ aStream: Stream, handle eventCode: Stream.Event) {
        switch eventCode {
        case Stream.Event.openCompleted:
            print("stream open completed")
        case Stream.Event.hasBytesAvailable:
            print("stream has bytes available to read")
        case Stream.Event.hasSpaceAvailable:
            print("stream has space available to write")
        case Stream.Event.errorOccurred:
            print("stream error occurred: \(aStream.streamError?.localizedDescription)")
        case Stream.Event.endEncountered:
            print("stream end encountered")
        default:
            print(eventCode)
        }
    }
}

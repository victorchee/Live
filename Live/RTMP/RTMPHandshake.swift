//
//  RTMPHandshake.swift
//  RTMP
//
//  Created by Migu on 2016/12/21.
//  Copyright © 2016年 VictorChee. All rights reserved.
//

import Foundation

class RTMPHandshake {
    var socket: RTMPSocket
    
    init(socket: RTMPSocket) {
        self.socket = socket
    }
    
    /// 握手开始于客户端发送C0、C1块。服务器收到C0或C1后发送S0和S1;
    /// 当客户端收齐S0和S1后，开始发送C2。当服务器收齐C0和C1后，开始发送S2;
    /// 当客户端和服务器分别收到S2和C2后，握手完成.
    final func shakeSimpleHand() {
        /// 为了减少通信次数
        /// ｜client｜Server ｜
        /// ｜－－－C0+C1—->|
        /// ｜<－－S0+S1+S2– |
        /// ｜－－－C2-－－－> ｜
        // Create C0 & C1
        var c0c1Chunk = Data()
        // C0块：1字节，表示客户端要求的RTMP版本，一般是0x03
        // Protocol version
        c0c1Chunk.append([UInt8(0x03)], count: 1) // 当前rtmp协议的版本号一致为“3”，0、1、2是旧版本号，已经弃用。4-31被保留为rtmp协议的未来实现版本使用；32-255不允许使用。如果服务器端或者客户端收到的C0字段解析出为非03，如果是0x06考虑使用openssl进行解密C1 C2 S1 S2,如果对端不支持加密字段可以选择以版本3来响应，也可以放弃握手。
        // C1块：1536字节，包括4字节时间戳，4字节0x00，1528字节随机数
        let timestamp = Date().timeIntervalSince1970
        // Combine 4B timestamp
        c0c1Chunk.append(Int32(timestamp).bigEndian.bytes, count: 4)
        // 4B 0x00
        let fourZeros = [UInt8](repeating: 0x00, count: 4)
        c0c1Chunk.append(fourZeros, count: fourZeros.count) // 简单握手这个字段必须都是0
        // 1528B random number
        for _ in 1...1528 {
            c0c1Chunk.append([UInt8(arc4random_uniform(0xff))], count: 1)
        }
        
        socket.write(data: c0c1Chunk)
        
        // Read 1B s0, 1536B s1, 1536B s2
        var s0s1s2 = [UInt8](repeating: 0x00, count: 3073)
        // S0块：1字节，表示服务器选择的RTMP版本，一般是0x03。
        // S1块：1536字节，包括4字节时间戳，4字节0x00，1528字节随机数。
        // S2块：1536字节，包括4字节c1的时间戳，4字节s1的时间戳，1528字节c1随机数
        socket.read(&s0s1s2, maxLength: 3073)
        
        // Send 1536B C2, C2 same with S1
        let c2Chunk = Array(s0s1s2[1...1536])
        // C2块：1536字节，包括4字节s1的时间戳，4字节c1的时间戳，1528字节s1随机数
        socket.write(bytes: c2Chunk)
    }
    
    /// 主要用于Flash播放器播放H264+aac流
    final func shakeComplexHand() {
        // 暂时不实现
    }
}

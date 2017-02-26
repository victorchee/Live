//
//  NumberByteOperator.swift
//  RTMP
//
//  Created by Migu on 2016/12/21.
//  Copyright © 2016年 VictorChee. All rights reserved.
//

import Foundation

extension ExpressibleByIntegerLiteral {
    var bytes: [UInt8] {
        var value = self
        return withUnsafeBytes(of: &value) { Array($0) }
    }
    
    init(bytes: [UInt8]) {
        self = bytes.withUnsafeBytes { $0.baseAddress!.load(as: Self.self)}
    }
}

class NumberByteOperator {
    static func readUInt16(_ inputStream: ByteArrayInputStream) -> UInt16 {
        var bytes = [UInt8](repeating: 0x00, count:2)
        inputStream.read(&bytes, maxLength: 2)
        return UInt16(bytes: bytes).bigEndian
    }
    
    static func readUInt24(_ inputStream: ByteArrayInputStream) -> UInt32 {
        var bytes = [UInt8](repeating: 0x00, count:3)
        inputStream.read(&bytes, maxLength: 3)
        return UInt32(bytes: [0x00] + bytes).bigEndian
    }
    
    static func readUInt32(_ inputStream: ByteArrayInputStream) -> UInt32 {
        var bytes = [UInt8](repeating: 0x00, count:4)
        inputStream.read(&bytes, maxLength: 4)
        return UInt32(bytes: [0x00] + bytes).bigEndian
    }
    
    static func readDouble(_ inputStream: ByteArrayInputStream) -> Double {
        var bytes = [UInt8](repeating: 0x00, count:8)
        inputStream.read(&bytes, maxLength: 8)
        return Double(bytes: bytes.reversed())
    }
}

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
    static func readUInt8(_ inputStream: ByteArrayInputStream) -> UInt8 {
        let size = MemoryLayout<UInt8>.size
        var bytes = [UInt8](repeating:0x00, count:size)
        inputStream.read(&bytes, maxLength:size)
        return UInt8(bytes:bytes)
    }
    
    static func readUInt16(_ inputStream: ByteArrayInputStream) -> UInt16 {
        let size = MemoryLayout<UInt16>.size
        var bytes = [UInt8](repeating:0x00, count:size)
        inputStream.read(&bytes, maxLength:size)
        return UInt16(bytes:bytes).bigEndian
    }
    
    static func readUInt24(_ inputStream: ByteArrayInputStream) -> UInt32 {
        let size = 3
        var bytes = [UInt8](repeating:0x00, count:size)
        inputStream.read(&bytes, maxLength:size)
        return UInt32(bytes:[0x00] + bytes).bigEndian
    }
    
    static func readUInt32(_ inputStream: ByteArrayInputStream) -> UInt32 {
        let size = MemoryLayout<UInt32>.size
        var bytes = [UInt8](repeating:0x00, count:size)
        inputStream.read(&bytes, maxLength:size)
        return UInt32(bytes:[0x00] + bytes).bigEndian
    }
    
    static func readDouble(_ inputStream: ByteArrayInputStream) -> Double {
        let size = MemoryLayout<Double>.size
        var bytes = [UInt8](repeating:0x00, count:size)
        inputStream.read(&bytes, maxLength:size)
        return Double(bytes:bytes.reversed())
    }
}

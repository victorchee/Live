//
//  ByteArrayInputStream.swift
//  RTMP
//
//  Created by VictorChee on 2016/12/21.
//  Copyright © 2016年 VictorChee. All rights reserved.
//

import Foundation

class ByteArrayInputStream {
    var byteArray: [UInt8]
    var currentPosition = 0
    var remainLength: Int {
        return byteArray.count - currentPosition
    }
    
    init(byteArray: [UInt8]) {
        self.byteArray = byteArray
    }
    
    /// Read max length bytes data
    func read(_ buffer: inout [UInt8], maxLength: Int) {
        if currentPosition + maxLength <= byteArray.count {
            for index in 0..<buffer.count {
                buffer[index] = byteArray[currentPosition+index]
            }
            currentPosition += maxLength
        } else {
            for index in 0..<byteArray.count-currentPosition {
                buffer[index] = byteArray[currentPosition+index]
            }
            currentPosition = byteArray.count
        }
    }
    
    /// Read data, but don't move position
    func tryRead(_ buffer: inout [UInt8], maxLength: Int) {
        if currentPosition + maxLength <= byteArray.count {
            for index in 0..<buffer.count {
                buffer[index] = byteArray[currentPosition+index]
            }
        } else {
            for index in 0..<byteArray.count-currentPosition {
                buffer[index] = byteArray[currentPosition+index]
            }
        }
    }
    
    /// Get 1B data
    @discardableResult
    func read() -> UInt8? {
        if currentPosition + 1 <= byteArray.count {
            let byteValue = byteArray[currentPosition]
            currentPosition += 1
            return byteValue
        } else {
            return nil
        }
    }
}

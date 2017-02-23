//
//  RTMPSocket.swift
//  Live
//
//  Created by Victor Chee on 2017/2/23.
//  Copyright © 2017年 VictorChee. All rights reserved.
//

import Foundation

final class RTMPSocket: NSObject {
    private var inputStream: InputStream?
    private var outputStream: OutputStream?
    
    open func connect(_ to: String, port: Int) {
        Stream.getStreamsToHost(withName: to, port: port, inputStream: &inputStream, outputStream: &outputStream)
        
        inputStream?.open()
        outputStream?.open()
    }
    
    func disconnect() {
        inputStream?.close()
        inputStream = nil
        outputStream?.close()
        outputStream = nil
    }
    
    func read() -> Data {
        return Data()
    }
    
    func write(_ data: Data) -> Int {
        return 0
    }
}

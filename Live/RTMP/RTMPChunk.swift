//
//  RTMPChunk.swift
//  RTMP
//
//  Created by Migu on 2016/12/21.
//  Copyright © 2016年 VictorChee. All rights reserved.
//

import Foundation

/// 消息分块、接受消息
final class RTMPChunk {
    /// RTMP 分成的Chunk有4中类型，可以通过 chunk basic header的 高两位指定，一般在拆包的时候会把一个RTMP消息拆成以 Type_0 类型开始的chunk，之后的包拆成 Type_3 类型的chunk
    enum ChunkType: UInt8 {
        /// Message Header占用11个字节，其他三种能表示的数据它都能表示，但在chunk stream的开始的第一个chunk和头信息中的时间戳后退（即值与上一个chunk相比减小，通常在回退播放的时候会出现这种情况）的时候必须采用这种格式
        case zero = 0
        /// Message Header占用7个字节，省去了表示msg stream id的4个字节，表示此chunk和上一次发的chunk所在的流相同，如果在发送端只和对端有一个流链接的时候可以尽量去采取这种格式。timestamp delta：占用3个字节，注意这里和type＝0时不同，存储的是和上一个chunk的时间差。类似上面提到的timestamp，当它的值超过3个字节所能表示的最大值时，三个字节都置为1，实际的时间戳差值就会转存到Extended Timestamp字段中，接受端在判断timestamp delta字段24个位都为1时就会去Extended timestamp中解析时机的与上次时间戳的差值。
        case one
        /// Message Header占用3个字节，相对于type＝1格式又省去了表示消息长度的3个字节和表示消息类型的1个字节，表示此chunk和上一次发送的chunk所在的流、消息的长度和消息的类型都相同。余下的这三个字节表示timestamp delta，使用同type＝1
        case two
        /// 0字节，它表示这个chunk的Message Header和上一个是完全相同的，自然就不用再传输一遍了。当它跟在Type＝0的chunk后面时，表示和前一个chunk的时间戳都是相同的。什么时候连时间戳都相同呢？就是一个Message拆分成了多个chunk，这个chunk和上一个chunk同属于一个Message。而当它跟在Type＝1或者Type＝2的chunk后面时，表示和前一个chunk的时间戳的差是相同的。比如第一个chunk的Type＝0，timestamp＝100，第二个chunk的Type＝2，timestamp delta＝20，表示时间戳为100+20=120，第三个chunk的Type＝3，表示timestamp delta＝20，时间戳为120+20=140
        case three
        
        func createBasicHeader(_ streamID: UInt16) -> [UInt8] {
            if streamID <= 63 {
                return [rawValue << 6 | UInt8(streamID)]
            } else if streamID <= 319 {
                return [rawValue << 6 | 0b00000000, UInt8(streamID - 64)]
            } else {
                return [rawValue << 6 | 0b00111111] + (streamID - 64).bigEndian.bytes
            }
        }
    }
    
    static let ControlChannel: UInt16 = 0x02
    static let CommandChannel: UInt16 = 0x03
    
    static let AudioChannel: UInt16 = 0x05
    static let VideoChannel: UInt16 = 0x06
    
    static var inWindowAckSize: UInt32!
    /// Window Acknowledgement Size 是设置接收端消息窗口大小，一般是2500000字节，即告诉客户端你在收到我设置的窗口大小的这么多数据之后给我返回一个ACK消息，告诉我你收到了这么多消息。在实际做推流的时候推流端要接收很少的服务器数据，远远到达不了窗口大小，所以基本不用考虑这点。而对于服务器返回的ACK消息一般也不做处理，我们默认服务器都已经收到了这么多消息。 之后要等待服务器对于connect的回应的，一般是把服务器返回的chunk都读完组成完整的RTMP消息，没有错误就可以进行下一步了
    static var outWindowAckChunkSize: UInt32 = 2500 * 1000
    
    /// Chunk basic header（1～3B）
    /// chunkType决定了消息头的编码格式（2b）
    var chunkType = ChunkType.zero // chunk type -> fmt
    /**chunkStreamID
     2~63
     +-+-+-+-+-+-+-+-+
     |fmt| stream id |
     +-+-+-+-+-+-+-+-+
     64~319
     +-+-+-+-+-+-+-+-|-+-+-+-+-+-+-+-+
     |fmt|     0     |   stream id   |
     +-+-+-+-+-+-+-+-|-+-+-+-+-+-+-+-+
     64~65599
     +-+-+-+-+-+-+-+-|-+-+-+-+-+-+-+-|-+-+-+-+-+-+-+-|-+-+-+-+-+-+-+-+
     |fmt|     1     |                    stream id                  |
     +-+-+-+-+-+-+-+-|-+-+-+-+-+-+-+-|-+-+-+-+-+-+-+-|-+-+-+-+-+-+-+-+
     */
    /// RTMP 的Chunk Steam ID是用来区分某一个chunk是属于哪一个message的 ,0和1是保留的。每次在发送一个不同类型的RTMP消息时都要有不用的chunk stream ID, 如上一个Message 是command类型的，之后要发送视频类型的消息，视频消息的chunk stream ID 要保证和上面 command类型的消息不同。每一种消息类型的起始chunk 的类型必须是 Type_0 类型的，表明这是一个新的消息的起始
    var chunkStreamID: UInt16 = 0
    
    /// Chunk message header
    var timestamp: UInt32! // 4B Timestamp
    var messageStreamID: UInt32! // 4B Stream ID
    var messageType: MessageType! // 1B message Type
    
    /// Split message into chunks
    class func splitMessage(_ message: RTMPMessage, chunkSize: Int, chunkType: ChunkType, chunkStreamID: UInt16) -> [UInt8]? {
        print(chunkType);
        var buffer = [UInt8]()
        
        // Basic header, just use chunkstream id < 64
        buffer += chunkType.createBasicHeader(chunkStreamID)
        
        // Message header（下面只处理了zero和one两种情况，two和three未处理）
        buffer += (message.timestamp >= 0xffffff ? [0xff, 0xff, 0xff] : message.timestamp.bigEndian.bytes[1...3]) // 3B timestamp
        buffer += UInt32(message.payloadLength).bigEndian.bytes[1...3] // 3B payload length
        buffer.append(message.messageType.rawValue) // 1B message type
        
        if chunkType == .zero {
            // Only type 0 has the message stream id
            buffer += message.messageStreamID.littleEndian.bytes // 4B message stream id
        }
        
        // 4B extended timestamp
        if message.timestamp >= 0xffffff {
            buffer += message.timestamp.bigEndian.bytes
        }
        
        if message.payloadLength < chunkSize {
            buffer += message.payload
        } else {
            var remainingCount = message.payloadLength
            var position = 0
            while remainingCount > chunkSize {
                buffer += message.payload[position..<(position+chunkSize)]
                remainingCount -= chunkSize
                position += chunkSize
                buffer.append(UInt8(0xc0 | (chunkStreamID & 0x3f))) // chunk type 3 header
            }
            buffer += message.payload[position..<(position+remainingCount)]
        }
        return buffer
    }
}

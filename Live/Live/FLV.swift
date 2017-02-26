//
//  FLV.swift
//  Live
//
//  Created by Migu on 2016/12/22.
//  Copyright © 2016年 VictorChee. All rights reserved.
//

import Foundation
import AVFoundation

enum FLVVideoCodec: UInt8 {
    case SorensonH263 = 2
    case Screen1      = 3
    case ON2VP6       = 4
    case ON2VP6Alpha  = 5
    case Screen2      = 6
    case AVC          = 7
    case Unknown      = 0xFF
    
    var isSupported:Bool {
        switch self {
        case .SorensonH263:
            return false
        case .Screen1:
            return false
        case .ON2VP6:
            return false
        case .ON2VP6Alpha:
            return false
        case .Screen2:
            return false
        case .AVC:
            return true
        case .Unknown:
            return false
        }
    }
}

enum FLVFrameType: UInt8 {
    case Key        = 1
    case Inter      = 2
    case Disposable = 3
    case Generated  = 4
    case Command    = 5
}

enum FLVAVCPacketType:UInt8 {
    case Seq = 0
    case Nal = 1
    case Eos = 2
}

enum FLVAACPacketType:UInt8 {
    case Seq = 0
    case Raw = 1
}

enum FLVSoundRate:UInt8 {
    case KHz5_5 = 0
    case KHz11  = 1
    case KHz22  = 2
    case KHz44  = 3
    
    var floatValue:Float64 {
        switch self {
        case .KHz5_5:
            return 5500
        case .KHz11:
            return 11025
        case .KHz22:
            return 22050
        case .KHz44:
            return 44100
        }
    }
}

enum FLVSoundSize:UInt8 {
    case Snd8bit = 0
    case Snd16bit = 1
}

enum FLVSoundType:UInt8 {
    case Mono = 0
    case Stereo = 1
}

enum FLVAudioCodec:UInt8 {
    case PCM           = 0
    case ADPCM         = 1
    case MP3           = 2
    case PCMLE         = 3
    case Nellymoser16K = 4
    case Nellymoser8K  = 5
    case Nellymoser    = 6
    case G711A         = 7
    case G711MU        = 8
    case AAC           = 10
    case Speex         = 11
    case MP3_8k        = 14
    case Unknown       = 0xFF
    
    var isSupported:Bool {
        switch self {
        case .PCM:
            return false
        case .ADPCM:
            return false
        case .MP3:
            return false
        case .PCMLE:
            return false
        case .Nellymoser16K:
            return false
        case .Nellymoser8K:
            return false
        case .Nellymoser:
            return false
        case .G711A:
            return false
        case .G711MU:
            return false
        case .AAC:
            return true
        case .Speex:
            return false
        case .MP3_8k:
            return false
        case .Unknown:
            return false
        }
    }
    
    var formatID:AudioFormatID {
        switch self {
        case .PCM:
            return kAudioFormatLinearPCM
        case .MP3:
            return kAudioFormatMPEGLayer3
        case .PCMLE:
            return kAudioFormatLinearPCM
        case .AAC:
            return kAudioFormatMPEG4AAC
        case .MP3_8k:
            return kAudioFormatMPEGLayer3
        default:
            return 0
        }
    }
    
    var headerSize:Int {
        switch self {
        case .AAC:
            return 2
        default:
            return 1
        }
    }
}

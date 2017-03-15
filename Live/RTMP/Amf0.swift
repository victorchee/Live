//
//  Amf0.swift
//  RTMP
//
//  Created by Migu on 2016/12/21.
//  Copyright © 2016年 VictorChee. All rights reserved.
//

import Foundation

class Amf0Data {
    enum Amf0DataType:UInt8 {
        case Amf0_Number            = 0x00
        case Amf0_Bool              = 0x01
        case Amf0_String            = 0x02
        /// Dictionary<String, Any?>
        case Amf0_Object            = 0x03
        case Amf0_MovieClip         = 0x04 // Reserved, not suppported
        case Amf0_Null              = 0x05
        case Amf0_Undefined         = 0x06
        case Amf0_Reference         = 0x07
        /// Map
        case Amf0_ECMAArray         = 0x08
        case Amf0_ObjectEnd         = 0x09
        case Amf0_StrictArray       = 0x0a
        case Amf0_Date              = 0x0b
        case Amf0_LongString        = 0x0c
        case Amf0_Unsupported       = 0x0d
        case Amf0_RecordSet         = 0x0e // Reserved, not supported
        case Amf0_XmlDocument       = 0x0f
        case Amf0_TypedObject       = 0x10
        case Amf0_AVMplushObject    = 0x11
    }
    
    var dataInBytes = [UInt8]()
    var dataLength: Int { return dataInBytes.count }
    
    static func create(_ inputStream: ByteArrayInputStream) -> Amf0Data? {
        guard let amfTypeRawValue = inputStream.read() else { return nil }
        // 第一个Byte是AMF类型
        guard let amf0Type = Amf0DataType(rawValue: amfTypeRawValue) else { return nil }
        var amf0Data: Amf0Data
        switch amf0Type {
        case .Amf0_Number:
            amf0Data = Amf0Number()
        case .Amf0_Bool:
            amf0Data = Amf0Boolean()
        case .Amf0_String:
            amf0Data = Amf0String()
        case .Amf0_Object:
            amf0Data = Amf0Object()
        case .Amf0_Null:
            amf0Data = Amf0Null()
        case .Amf0_Undefined:
            amf0Data = Amf0Undefined()
        case .Amf0_ECMAArray:
            amf0Data = Amf0ECMAArray()
        case .Amf0_StrictArray:
            amf0Data = Amf0StrictArray()
        case .Amf0_Date:
            amf0Data = Amf0Date()
        default:
            return nil
        }
        amf0Data.decode(inputStream)
        return amf0Data
    }
    
    func decode(_ inputStream: ByteArrayInputStream) { }
}

class Amf0Number: Amf0Data {
    var value: Double!
    
    override init() { }
    
    init(value: Any) {
        switch value {
        case let value as Double:
            self.value = value
        case let value as Int:
            self.value = Double(value)
        case let value as Int32:
            self.value = Double(value)
        case let value as UInt32:
            self.value = Double(value)
        case let value as Float64:
            self.value = Double(value)
        default:
            break
        }
    }
    
    override var dataInBytes: [UInt8] {
        get {
            guard super.dataInBytes.isEmpty else {
                return super.dataInBytes
            }
            // 1B type
            super.dataInBytes.append(Amf0DataType.Amf0_Number.rawValue)
            // 8B double value
            super.dataInBytes += value.bytes.reversed()
            return super.dataInBytes
        }
        set {
            super.dataInBytes = newValue
        }
    }
    
    override func decode(_ inputStream: ByteArrayInputStream) {
        // 1B amf type has skip
        self.value = NumberByteOperator.readDouble(inputStream)
    }
    
    static func decode(_ inputStream: ByteArrayInputStream) -> Double {
        // skip 1B amf type
        inputStream.read()
        return NumberByteOperator.readDouble(inputStream)
    }
}

class Amf0Null: Amf0Data {
    override var dataInBytes: [UInt8] {
        get {
            guard super.dataInBytes.isEmpty else {
                return super.dataInBytes
            }
            // only 1B amf null type, no value
            super.dataInBytes.append(Amf0DataType.Amf0_Null.rawValue)
            return super.dataInBytes
        }
        set {
            super.dataInBytes = newValue
        }
    }
}

class Amf0Boolean: Amf0Data {
    private var value = false
    
    override init() { }
    
    init(value: Bool) {
        self.value = value
    }
    
    override var dataInBytes: [UInt8] {
        get {
            guard super.dataInBytes.isEmpty else {
                return super.dataInBytes
            }
            // 1B type
            super.dataInBytes.append(Amf0DataType.Amf0_Bool.rawValue)
            // Write value
            super.dataInBytes.append(value ? 0x01 : 0x00)
            return super.dataInBytes
        }
        set {
            super.dataInBytes = newValue
        }
    }
    
    override func decode(_ inputStream: ByteArrayInputStream) {
        // 1B amf type has skip
        self.value = (inputStream.read() == 0x01)
    }
}

class Amf0String: Amf0Data {
    private var value: String!
    
    override init() { }
    
    init(value: String) {
        self.value = value
    }
    
    override var dataInBytes: [UInt8] {
        get {
            guard super.dataInBytes.isEmpty else {
                return super.dataInBytes
            }
            let isLongString = UInt32(value.characters.count) > UInt32(UInt16.max)
            // 1B type
            super.dataInBytes.append(isLongString ? Amf0DataType.Amf0_LongString.rawValue : Amf0DataType.Amf0_String.rawValue)
            let stringInBytes = [UInt8](value.utf8)
            // Value length
            if isLongString {
                // 4B, big endian
                super.dataInBytes += UInt32(stringInBytes.count).bigEndian.bytes
            } else {
                // 2B, big endian
                super.dataInBytes += UInt16(stringInBytes.count).bigEndian.bytes
            }
            // Value in bytes
            super.dataInBytes += stringInBytes
            return super.dataInBytes
        }
        set {
            super.dataInBytes = newValue
        }
    }
    
    override func decode(_ inputStream: ByteArrayInputStream) {
        // 1B amf type has skipped
        let stringLength = NumberByteOperator.readUInt16(inputStream)
        var stringInBytes = [UInt8](repeating: 0x00, count: Int(stringLength))
        inputStream.read(&stringInBytes, maxLength: Int(stringLength))
        
        self.value = String(bytes: stringInBytes, encoding: .utf8)
    }
    
    static func decode(_ inputStream: ByteArrayInputStream, isAmfObjectKey: Bool) -> String? {
        if !isAmfObjectKey {
            // Skip 1B amf type
            inputStream.read()
        }
        
        let stringLength = NumberByteOperator.readUInt16(inputStream) // 2B的长度数据
        var stringInBytes = [UInt8](repeating: 0x00, count: Int(stringLength))
        inputStream.read(&stringInBytes, maxLength: Int(stringLength))
        return String(bytes: stringInBytes, encoding: .utf8)
    }
}

class Amf0Object: Amf0Data {
    /// 结尾
    let endMark: [UInt8] = [0x00, 0x00, 0x09]
    var properties = [String: Amf0Data]()
    
    func setProperties(key: String, value: Any) {
        switch value {
        case let value as Double:
            properties[key] = Amf0Number(value: value)
        case let value as Int:
            properties[key] = Amf0Number(value: value)
        case let value as String:
            properties[key] = Amf0String(value: value)
        case let value as Bool:
            properties[key] = Amf0Boolean(value: value)
        default:
            properties[key] = Amf0Number(value: value)
            break
        }
    }
    
    override var dataInBytes: [UInt8] {
        get {
            guard super.dataInBytes.isEmpty else {
                return super.dataInBytes
            }
            // 1B type
            super.dataInBytes.append(Amf0DataType.Amf0_Object.rawValue)
            for (key, value) in properties {
                let keyInBytes = [UInt8](key.utf8)
                // Key
                super.dataInBytes += UInt16(keyInBytes.count).bigEndian.bytes
                super.dataInBytes += keyInBytes
                // Value
                super.dataInBytes += value.dataInBytes
            }
            super.dataInBytes += endMark
            return super.dataInBytes
        }
        set {
            super.dataInBytes = newValue
        }
    }
    
    override func decode(_ inputStream: ByteArrayInputStream) {
        // 1B amf type has skipped
        var buffer = [UInt8](repeating: 0x00, count:3)
        while true {
            // try read if catch the object end
            inputStream.tryRead(&buffer, maxLength: 3)
            if buffer[0] == endMark[0] && buffer[1] == endMark[1] && buffer[2] == endMark[2] {
                inputStream.read(&buffer, maxLength: 3)
                break
            }
            guard let key = Amf0String.decode(inputStream, isAmfObjectKey: true) else { return }
            guard let value = Amf0Data.create(inputStream) else { return }
            
            properties[key] = value
        }
    }
}

class Amf0StrictArray: Amf0Data {
    private var arrayItems = [Amf0Data]()
    override var dataInBytes: [UInt8] {
        get {
            guard super.dataInBytes.isEmpty else {
                return super.dataInBytes
            }
            // 1B type
            super.dataInBytes.append(Amf0DataType.Amf0_StrictArray.rawValue)
            // 4B count
            super.dataInBytes += UInt32(arrayItems.count).bigEndian.bytes
            // Items
            for item in arrayItems {
                super.dataInBytes += item.dataInBytes
            }
            return super.dataInBytes
        }
        set {
            super.dataInBytes = newValue
        }
    }
    
    override func decode(_ inputStream: ByteArrayInputStream) {
        // 1B amf type has skipped
        let arrayCount = NumberByteOperator.readUInt32(inputStream)
        for _ in 1...arrayCount {
            guard let item = Amf0Data.create(inputStream) else { return }
            arrayItems.append(item)
        }
    }
}

class Amf0ECMAArray: Amf0Object {
    override var dataInBytes: [UInt8] {
        get {
            guard super.dataInBytes.isEmpty else {
                return super.dataInBytes
            }
            
            // 1B type
            super.dataInBytes.append(Amf0DataType.Amf0_ECMAArray.rawValue)
            super.dataInBytes += UInt32(properties.count).bigEndian.bytes
            for (key, value) in properties {
                super.dataInBytes += [UInt8](key.utf8)
                super.dataInBytes += value.dataInBytes
            }
            super.dataInBytes += endMark
            return super.dataInBytes
        }
        set {
            super.dataInBytes = newValue
        }
    }
}

class Amf0Undefined: Amf0Data {
    override var dataInBytes: [UInt8] {
        get {
            guard super.dataInBytes.isEmpty else {
                return super.dataInBytes
            }
            // Only 1B amf type
            super.dataInBytes.append(Amf0DataType.Amf0_Undefined.rawValue)
            return super.dataInBytes
        }
        set {
            super.dataInBytes = newValue
        }
    }
    
    override func decode(_ inputStream: ByteArrayInputStream) {
        // 1B amf type has skipped
        // Amf type has been read, nothing still need to be decode
    }
}

class Amf0Date: Amf0Data {
    private var value: Date!
    override var dataInBytes: [UInt8] {
        get {
            guard super.dataInBytes.isEmpty else {
                return super.dataInBytes
            }
            
            // 1B type
            super.dataInBytes.append(Amf0DataType.Amf0_ECMAArray.rawValue)
            super.dataInBytes += (value.timeIntervalSince1970 * 1000).bytes.reversed()
            // 2B end
            super.dataInBytes += [0x00, 0x00]
            return super.dataInBytes
        }
        set {
            super.dataInBytes = newValue
        }
    }
    
    override func decode(_ inputStream: ByteArrayInputStream) {
        // 1B amf type has skipped
        value = Date(timeIntervalSince1970: NumberByteOperator.readDouble(inputStream) / 1000)
    }
}

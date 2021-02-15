//
//  XMRUtils.swift
//  DigitalMiner
//
//  Created by Jinxiao on 2018/8/3.
//  Copyright © 2018 debugeek. All rights reserved.
//

import Foundation

extension Data {

    // Convert 0 ... 9, a ... f, A ...F to their decimal value,
    // return nil for all other input characters
    fileprivate func decodeNibble(_ u: UInt16) -> UInt8? {
        switch(u) {
        case 0x30 ... 0x39:
            return UInt8(u - 0x30)
        case 0x41 ... 0x46:
            return UInt8(u - 0x41 + 10)
        case 0x61 ... 0x66:
            return UInt8(u - 0x61 + 10)
        default:
            return nil
        }
    }

    init?(hexString string: String) {
        var str = string
        if str.count%2 != 0 {
            // insert 0 to get even number of chars
            str.insert("0", at: str.startIndex)
        }

        let utf16 = str.utf16
        self.init(capacity: utf16.count/2)

        var i = utf16.startIndex
        while i != str.utf16.endIndex {
            guard let hi = decodeNibble(utf16[i]), let lo = decodeNibble(utf16[utf16.index(i, offsetBy: 1, limitedBy: utf16.endIndex)!]) else {
                    return nil
            }
            var value = hi << 4 + lo
            self.append(&value, count: 1)
            i = utf16.index(i, offsetBy: 2, limitedBy: utf16.endIndex)!
        }
    }

    func hexString(uppercase: Bool = false) -> String {
        let format = uppercase ? "%02hhX" : "%02hhx"
        return map { String(format: format, $0) }.joined()
    }

    var bytes: [UInt8] {
        return [UInt8](self)
    }
}

extension Array where Element == UInt8 {
    var data: Data {
        return Data(self)
    }
}

struct VarIntCoder {

    public func encode(UInt64 value: UInt64) -> [UInt8] {
        var buffer = [UInt8]()
        var val: UInt64 = value

        while val >= 0x80 {
            buffer.append((UInt8(truncatingIfNeeded: val) | 0x80))
            val >>= 7
        }

        buffer.append(UInt8(val))
        return buffer
    }

    public func decode(UInt64 buffer: [UInt8]) -> (UInt64, Int) {
        var output: UInt64 = 0
        var counter = 0
        var shifter: UInt64 = 0

        for byte in buffer {
            if byte < 0x80 {
                if counter > 9 || counter == 9 && byte > 1 {
                    return (0, -(counter + 1))
                }
                return (output | UInt64(byte) << shifter, counter + 1)
            }

            output |= UInt64(byte & 0x7f) << shifter
            shifter += 7
            counter += 1
        }
        return (0, 0)
    }

    public func encode(Int64 value: Int64) -> [UInt8] {
        let unsignedValue = UInt64(value) << 1
        return encode(UInt64: unsignedValue)
    }

    public func decode(Int64 buffer: [UInt8]) -> (Int64, Int) {
        let (unsignedValue, bytesRead) = decode(UInt64: buffer)
        var value = Int64(unsignedValue >> 1)

        if unsignedValue & 1 != 0 {
            value = ~value
        }

        return (value, bytesRead)
    }

}

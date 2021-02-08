//
//  XMRJob.swift
//  XMRMiner
//
//  Created by Jinxiao on 2018/8/2.
//  Copyright © 2018 debugeek. All rights reserved.
//

import Foundation

struct XMRHash {
    static let size = 32

    fileprivate var raw = [UInt8]()

    var bytes: [UInt8] {
        get { return raw }
        set { raw = newValue }
    }
    init(bytes: [UInt8]) { self.bytes = bytes }

    var uints: [UInt64] {
        get {
            let length = Int(ceil(Double(raw.count)/Double(MemoryLayout<UInt64>.size)))
            var buffer = [UInt64](repeating: 0, count: length)
            memmove(&buffer, raw, length*MemoryLayout<UInt64>.size)
            return buffer
        }
        set {
            let length = newValue.count*MemoryLayout<UInt64>.size
            var buffer = [UInt8](repeating: 0, count: length)
            memmove(&buffer, newValue, length)
            raw = buffer
        }
    }
    init(uints: [UInt64]) { self.uints = uints }
}

struct XMRJob {

    let jobId: String

    let target: UInt64

    let blob: Data

}

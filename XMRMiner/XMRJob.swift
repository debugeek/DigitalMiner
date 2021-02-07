//
//  XMRJob.swift
//  XMRMiner
//
//  Created by Jinxiao on 2018/8/2.
//  Copyright © 2018 debugeek. All rights reserved.
//

import Foundation

struct XMRJob {

    var jobId: String
    var blob: Data
    var target: UInt64

    var difficulty: UInt64 {
        get {
            return 0xFFFFFFFFFFFFFFFF/target
        }
    }


    init?(jobId: String, blob: String, target: String) {
        self.jobId = jobId

        guard let blob = Data(hexString: blob), let target = Data(hexString: target) else {
            return nil
        }

        self.blob = blob

        if let target32 = target.uint32() {
            let a: UInt64 = 0xFFFFFFFFFFFFFFFF
            let b: UInt64 = 0xFFFFFFFF
            self.target = a / (b / UInt64(target32))
        } else if let target64 = target.uint64() {
            self.target = target64
        } else {
            return nil
        }
    }


}

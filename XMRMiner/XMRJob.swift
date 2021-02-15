//
//  XMRJob.swift
//  XMRMiner
//
//  Created by Jinxiao on 2018/8/2.
//  Copyright © 2018 debugeek. All rights reserved.
//

import Foundation

struct XMRJob {

    let jobId: String

    let target: UInt64

    let blob: Data

    let height: UInt64

    let version: UInt64
    
}

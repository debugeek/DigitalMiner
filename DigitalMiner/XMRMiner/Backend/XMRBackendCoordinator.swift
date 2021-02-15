//
//  XMRBackendCoordinator.swift
//  DigitalMiner
//
//  Created by Xiao Jin on 2021/2/8.
//  Copyright © 2021 debugeek. All rights reserved.
//

import Foundation
import Atomics

class XMRBackendCoordinator {
    static let shared = XMRBackendCoordinator()

    private let nonce = ManagedAtomic<UInt32>(0)

    private(set) var blob: Data?
    private(set) var target: UInt64 = 0
    private(set) var height: UInt64 = 0
    private(set) var version: UInt64 = 0

    func update(job: XMRJob) {
        self.blob = job.blob
        self.target = job.target
        self.height = job.height
        self.version = job.version
        nonce.store(UInt32.max - arc4random(), ordering: .relaxed)
    }

    func nextNonce() -> UInt32 {
        return nonce.wrappingDecrementThenLoad(ordering: .relaxed)
    }
}

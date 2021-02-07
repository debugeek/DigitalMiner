//
//  XMRBackend.swift
//  XMRMiner
//
//  Created by Jinxiao on 2018/8/4.
//  Copyright © 2018 debugeek. All rights reserved.
//

import Foundation

protocol XMRBackendDelegate {

    func backend(backend: XMRBackend, didFoundNonce nonce: String, hash: String, jobId: String)

}


class XMRBackend {

    var nonce: UInt32 = 0

    var job: XMRJob? {
        didSet {
            guard let job = job else {
                return
            }
            schedule(job: job)
        }
    }

    init() { }

    func schedule(job: XMRJob) { }

    func drop() {}

    func nextNonce(nonce: UInt32) -> UInt32 {
        defer {
            self.nonce = self.nonce + nonce
        }
        return self.nonce
    }

    var delegate: XMRBackendDelegate?

    var hashrate: Double = 0
    
}

//
//  XMRBackend.swift
//  DigitalMiner
//
//  Created by Jinxiao on 2018/8/4.
//  Copyright © 2018 debugeek. All rights reserved.
//

import Foundation

protocol XMRBackendDelegate {

    func backend(backend: XMRBackend, didFoundHash hash: String, forNonce nonce: String, jobId: String)

}


class XMRBackend {

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

    var delegate: XMRBackendDelegate?

    var hashrate: Double = 0
    
}

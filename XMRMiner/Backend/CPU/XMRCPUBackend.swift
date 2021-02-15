//
//  XMRCPUBackend.swift
//  XMRMiner
//
//  Created by Jinxiao on 2018/8/4.
//  Copyright © 2018 debugeek. All rights reserved.
//

import Foundation

protocol XMRCPUThreadDelegate {
    func thread(CPUThread: XMRCPUThread, acquiresBlob blob: inout Data?, target: inout UInt64, nonce: inout UInt32, height: inout UInt64, version: inout UInt64)
    func thread(CPUThread: XMRCPUThread, didFoundHash hash: String, forNonce nonce: String)
    func thread(CPUThread: XMRCPUThread, didUpdateHashrate hashrate: Double)
}

class XMRCPUThread: Thread {

    var delegate: XMRCPUThreadDelegate?

    private var hashCount: UInt64 = 0
    private var hashRate: Double = 0

    override func main() {
        var bytes = [Int8](repeating: 0, count: 32)
        var lluints = [UInt64](repeating: 0, count: 4)

        var starttime = timeval()
        var endtime = timeval()

        while !isCancelled {
            var blob: Data?
            var nonce: UInt32 = 0
            var target: UInt64 = 0
            var height: UInt64 = 0
            var version: UInt64 = 0

            delegate?.thread(CPUThread: self, acquiresBlob: &blob, target: &target, nonce: &nonce, height: &height, version: &version)

            if var blob = blob {
                blob.withUnsafeMutableBytes { [length = UInt32(blob.count)] (rawBufferPtr: UnsafeMutableRawBufferPointer) in
                    guard let ptr = rawBufferPtr.baseAddress else {
                        return
                    }

                    gettimeofday(&starttime, nil)

                    // hardcode nonce offset = 39
                    memmove(ptr + 39, &nonce, 4)
                    xmr_hash(ptr, length, &bytes, version, height)
                    memmove(&lluints, &bytes, 32)

                    gettimeofday(&endtime, nil)

                    if lluints[3] < target {
                        delegate?.thread(CPUThread: self,
                                         didFoundHash: Data(bytes: bytes, count: 32).hexString(),
                                         forNonce: Data(bytes: &nonce, count: 4).hexString())
                    }

                    let duration = Double(endtime.tv_sec - starttime.tv_sec)*1000000 + Double(endtime.tv_usec - starttime.tv_usec)
                    delegate?.thread(CPUThread: self, didUpdateHashrate: 1.0/(duration/1000000))
                }
            }
        }
    }
}

class XMRCPUBackend: XMRBackend, XMRCPUThreadDelegate {

    lazy var thread: XMRCPUThread = {
        let thread = XMRCPUThread()
        thread.delegate = self
        return thread
    }()

    override func schedule(job: XMRJob) {
        super.schedule(job: job)

        if !self.thread.isExecuting {
            self.thread.start()
        }
    }

    override func drop() {
        super.drop()

        if !self.thread.isCancelled {
            self.thread.cancel()
        }
    }

    func thread(CPUThread: XMRCPUThread, acquiresBlob blob: inout Data?, target: inout UInt64, nonce: inout UInt32, height: inout UInt64, version: inout UInt64) {
        let coordinator = XMRBackendCoordinator.shared
        blob = coordinator.blob
        target = coordinator.target
        height = coordinator.height
        version = coordinator.version
        nonce = coordinator.nextNonce()
    }

    func thread(CPUThread: XMRCPUThread, didFoundHash hash: String, forNonce nonce: String) {
        guard let jobId = self.job?.jobId else {
            return
        }
        delegate?.backend(backend: self, didFoundHash: hash, forNonce: nonce, jobId: jobId)
    }

    func thread(CPUThread: XMRCPUThread, didUpdateHashrate hashrate: Double) {
        self.hashrate = hashrate
    }
    
}



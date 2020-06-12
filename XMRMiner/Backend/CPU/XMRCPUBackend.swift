//
//  XMRCPUBackend.swift
//  XMRMiner
//
//  Created by Jinxiao on 2018/8/4.
//  Copyright © 2018 debugeek. All rights reserved.
//

import Foundation

protocol XMRCPUThreadDelegate {
    func thread(CPUThread: XMRCPUThread, requireJobForTimestamp: TimeInterval) -> XMRJob?
    func thread(CPUThread: XMRCPUThread, requireNonceForTimestamp: TimeInterval) -> UInt32?
    func thread(CPUThread: XMRCPUThread, didFoundNonce nonce: UInt32, hash: UnsafeRawPointer, length: Int)
    func thread(CPUThread: XMRCPUThread, didUpdateHashrate hashrate: Double)
}

class XMRCPUThread: Thread {

    var delegate: XMRCPUThreadDelegate?

    override func main() {

        let hash = UnsafeMutablePointer<UInt8>.allocate(capacity: 32)

        while !isCancelled {
            let timestamp = Date.timeIntervalBetween1970AndReferenceDate

            guard var job = delegate?.thread(CPUThread: self, requireJobForTimestamp: timestamp),
                let nonce = delegate?.thread(CPUThread: self, requireNonceForTimestamp: timestamp) else {
                Thread.sleep(forTimeInterval: 0.01)
                continue
            }

            var blob: UnsafeMutablePointer<Int8>?
            job.blob.withUnsafeMutableBytes { (bytes: UnsafeMutablePointer<Int8>) -> Void in
                blob = bytes
            }

            let beginTime = CFAbsoluteTimeGetCurrent()

            xmr_hash(blob, UInt32(job.blob.count), nonce, hash)

            if let target = Data(bytes: hash.advanced(by: 24), count: MemoryLayout<UInt64>.size).uint64(), target < job.target {
                delegate?.thread(CPUThread: self, didFoundNonce: nonce, hash: hash, length: 32)
            }

            let endTime = CFAbsoluteTimeGetCurrent()
            delegate?.thread(CPUThread: self, didUpdateHashrate: 1.0/(endTime - beginTime))
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

    func thread(CPUThread: XMRCPUThread, requireJobForTimestamp: TimeInterval) -> XMRJob? {
        return self.job
    }

    func thread(CPUThread: XMRCPUThread, requireNonceForTimestamp: TimeInterval) -> UInt32? {
        return self.nextNonce(nonce: 1)
    }

    func thread(CPUThread: XMRCPUThread, didFoundNonce nonce: UInt32, hash: UnsafeRawPointer, length: Int) {
        guard let jobID = self.job?.jobID else {
            return
        }

        var nonce = nonce
        let nonceString = Data(bytes: &nonce, count: MemoryLayout<UInt32>.size(ofValue: nonce)).hexString()

        let hashData = Data(bytes: hash, count: length)
        let hashString = hashData.hexString()

        delegate?.backend(backend: self, didFoundNonce: nonceString, hash: hashString, jobID: jobID)
    }

    func thread(CPUThread: XMRCPUThread, didUpdateHashrate hashrate: Double) {
        self.hashrate = hashrate
    }
}



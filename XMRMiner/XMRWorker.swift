//
//  XMRWorker.swift
//  XMRMiner
//
//  Created by Jinxiao on 2018/8/2.
//  Copyright © 2018 debugeek. All rights reserved.
//

import Foundation

public protocol XMRWorkerDelegate {
    func worker(worker: XMRWorker, didLoginedWithWorkerId workerId: String)
    func worker(worker: XMRWorker, didReceivedJobWithJobId jobId: String)
    func worker(worker: XMRWorker, didSubmittedNoviceWithError error: Error?)
    func worker(worker: XMRWorker, didOccurredError error: Error?)
}

public class XMRWorker {

    lazy var identifier: String = {
        return UUID().uuidString
    } ()

    var session: XMRPoolSession

    var backends: [XMRCPUBackend] = []

    var job: XMRJob?

    public var hashrate: Double {
        get {
            var hashrate: Double = 0
            for backend in backends {
                hashrate += backend.hashrate
            }
            return hashrate
        }
    }

    public var delegate: XMRWorkerDelegate?

    public init?(identifier: String, host: String, port: Int, username: String, password: String) {
        guard let session = XMRPoolSession(host: host, port: port, username: username, password: password) else {
            return nil
        }

        self.session = session
        self.session.delegate = self
    }


    public func start() {
        session.connect()
    }

    public func stop() {
        session.disconnect()

        for backend in backends {
            backend.drop()
        }
    }

    func balanceJobs() {
        if backends.count == 0 {
            return
        }

        var nonce: UInt32 = 0
        let steps: UInt32 = UInt32.max/UInt32(backends.count)
        for backend in backends {
            backend.nonce = nonce
            backend.job = job
            nonce += steps
        }
    }

}

extension XMRWorker: XMRBackendDelegate {

    func backend(backend: XMRBackend, didFoundNonce nonce: String, hash: String, jobId: String) {
        session.submit(jobId: jobId, nonce: nonce, hash: hash) { [weak self] (error) in
            guard let strongSelf = self else { return }
            strongSelf.delegate?.worker(worker: strongSelf, didSubmittedNoviceWithError: error)
        }
    }

}

extension XMRWorker: XMRPoolSessionDelegate {

    func session(session _: XMRPoolSession, didLoginedWithWorkerId workerId: String) {
        var ncpu: Int = 0
        var size = MemoryLayout<Int>.size
        sysctlbyname("hw.ncpu", &ncpu, &size, nil, 0)

        for _ in 0...ncpu - 1 {
            let CPUBackend = XMRCPUBackend()
            CPUBackend.delegate = self
            backends.append(CPUBackend)
        }

        delegate?.worker(worker: self, didLoginedWithWorkerId: workerId)
    }

    func session(session _: XMRPoolSession, didReceivedJob newJob: XMRJob) {
        if let oldJob = job {
            if oldJob.jobId == newJob.jobId {
                return
            }

            if oldJob.blob == newJob.blob {
                job?.jobId = newJob.jobId
                job?.target = newJob.target
                return
            }
        }

        job = newJob

        balanceJobs()

        delegate?.worker(worker: self, didReceivedJobWithJobId: newJob.jobId)
    }

    func session(session _: XMRPoolSession, didReceivedError error: Error) {
        stop()
        
        delegate?.worker(worker: self, didOccurredError: error)
    }

}

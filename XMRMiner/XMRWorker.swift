//
//  XMRWorker.swift
//  XMRMiner
//
//  Created by Jinxiao on 2018/8/2.
//  Copyright © 2018 debugeek. All rights reserved.
//

import Foundation

public protocol XMRWorkerDelegate {
    func workerDidLogined(_ worker: XMRWorker)
    func workerDidReceivedJob(_ worker: XMRWorker)
    func workerDiSubmitted(_ worker: XMRWorker)
    func workerDidReceivedError(_ worker: XMRWorker)
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

    func backend(backend: XMRBackend, didFoundNonce nonce: String, hash: String, jobID: String) {
        session.submit(jobID: jobID, nonce: nonce, hash: hash)
    }

}

extension XMRWorker: XMRPoolSessionDelegate {

    func session(session _: XMRPoolSession, didLoginedWithWorkerID workerID: String) {
        delegate?.workerDidLogined(self)

        var ncpu: Int = 0
        var size = MemoryLayout<Int>.size
        sysctlbyname("hw.ncpu", &ncpu, &size, nil, 0)

        for _ in 0...ncpu - 1 {
            let CPUBackend = XMRCPUBackend()
            CPUBackend.delegate = self
            backends.append(CPUBackend)
        }
    }

    func session(session _: XMRPoolSession, didReceivedJob newJob: XMRJob) {
        if let oldJob = job {
            if oldJob.jobID == newJob.jobID {
                return
            }

            if oldJob.blob == newJob.blob {
                job?.jobID = newJob.jobID
                job?.target = newJob.target
                return
            }
        }

        job = newJob

        balanceJobs()

        delegate?.workerDidReceivedJob(self)
    }

    func session(session _: XMRPoolSession, didReceivedError error: Error) {
        delegate?.workerDidReceivedError(self)

        stop()

        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            self.start()
        }
    }

}

//
//  XMRPoolSession.swift
//  XMRMiner
//
//  Created by Jinxiao on 2018/8/2.
//  Copyright © 2018 debugeek. All rights reserved.
//

import Foundation

typealias XMRParameters = [String: Any]

let XMRPoolSessionErrorDomain = "XMRPoolSessionErrorDomain"

protocol XMRPoolSessionDelegate {
    func session(session _: XMRPoolSession, didLoginedWithWorkerID workerID: String)
    func session(session _: XMRPoolSession, didReceivedJob job: XMRJob)
    func session(session _: XMRPoolSession, didReceivedError error: Error)
}

public class XMRPoolSession {

    let username: String
    let password: String

    let stream: XMRStream

    var workerID: String?

    var delegate: XMRPoolSessionDelegate?

    lazy var timer: XMRTimer = {
        let timer = XMRTimer(timeInterval: 20)
        timer.eventHandler = { [weak self] in
            if let workerID = self?.workerID {
                self?.fetch(workerID: workerID)
            }
        }
        return timer
    }()

    public init?(host: String, port: Int, username: String, password: String) {
        self.username = username
        self.password = password

        guard let stream = XMRStream(host: host, port: port) else {
            return nil
        }

        self.stream = stream
        self.stream.delegate = self
    }

    public func connect() {
        stream.open()

        login()
    }

    public func disconnect() {
        stream.close()

        workerID = nil
    }

    public func login() {
        let params: XMRParameters = ["method": "login", "params": ["login": username, "pass": password, "agent": "digital-miner/1.0"], "id": 1]
        send(params: params)
    }

    public func submit(jobID: String, nonce: String, hash: String) {
        let params: XMRParameters = ["method": "submit", "params": ["id": workerID, "job_id": jobID, "nonce": nonce, "result": hash], "id": 1]
        send(params: params)
    }

    public func fetch(workerID: String) {
        let params: XMRParameters = ["method": "getjob", "params": ["id": workerID], "id": 1]
        send(params: params)
    }

    private func send(params: XMRParameters, completion: ((XMRParameters) -> Void)? = nil) {
        guard let tail = "\n".data(using: .utf8) else {
            return
        }

        do {
            let data = try JSONSerialization.data(withJSONObject: params, options: [])
            stream.send(data: data + tail)
        } catch {}
    }

    func handleResponse(response: XMRParameters) {
        timer.reschedule()

        if let method = response["method"] as? String {
            if method == "mining.set_extranonce" {
                print("Detected buggy NiceHash pool code. Workaround engaged.")
            } else if method == "job", let params = response["params"] as? [String: Any] {
                handleJob(params: params)
            } else {
                print("Unsupported server method")
            }
        } else if let error = response["error"] as? [String: Any], let code = error["code"] as? Int, let description = error["message"] as? String {
            handleError(error: NSError(domain: XMRPoolSessionErrorDomain, code: code, userInfo: [NSLocalizedDescriptionKey: description]))
        } else if let result = response["result"] as? [String: Any], let workerID = result["id"] as? String, let params = result["job"] as? [String: Any] {
            handleLogin(workerID: workerID)
            handleJob(params: params)
        } else {

        }
    }

    func handleError(error: Error) {
        timer.suspend()

        delegate?.session(session: self, didReceivedError: error)
    }

    func handleLogin(workerID: String) {
        self.workerID = workerID

        timer.resume()

        delegate?.session(session: self, didLoginedWithWorkerID: workerID)
    }

    func handleJob(params: XMRParameters) {
        guard let jobID = params["job_id"] as? String, let blob = params["blob"] as? String, let target = params["target"] as? String else {
            return
        }

        guard let job = XMRJob(jobID: jobID, blob: blob, target: target) else {
            return
        }

        delegate?.session(session: self, didReceivedJob: job)
    }
}


// XMRStreamDelegate
extension XMRPoolSession: XMRStreamDelegate {

    func stream(stream: XMRStream, didReceivedData data: Data?, error: Error?) {
        if let error = error {
            handleError(error: error)
        } else if let data = data {
            do {
                if let response = try JSONSerialization.jsonObject(with: data, options: []) as? XMRParameters {
                    handleResponse(response: response)
                } else {
                    handleError(error: NSError(domain: XMRPoolSessionErrorDomain, code: 0, userInfo: nil))
                }
            } catch {}
        } else {
            handleError(error: NSError(domain: XMRPoolSessionErrorDomain, code: 0, userInfo: nil))
        }
    }
    
}

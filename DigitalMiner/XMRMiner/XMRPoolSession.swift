//
//  XMRPoolSession.swift
//  DigitalMiner
//
//  Created by Jinxiao on 2018/8/2.
//  Copyright © 2018 debugeek. All rights reserved.
//

import Foundation

let XMRPoolSessionErrorDomain = "XMRPoolSessionErrorDomain"

protocol XMRPoolSessionDelegate {
    func session(session: XMRPoolSession, didLoginedWithWorkerId workerId: String)
    func session(session: XMRPoolSession, didReceivedJob job: XMRJob)
    func session(session: XMRPoolSession, didReceivedError error: Error)
}

public class XMRPoolSession {

    let username: String
    let password: String

    let stream: XMRStream

    var workerId: String?

    var delegate: XMRPoolSessionDelegate?

    private var seq: UInt32 = 0
    private var completions = [UInt32: ((Error?, [String: Any]?) -> Void)]()

    lazy var timer: XMRTimer = {
        let timer = XMRTimer(timeInterval: 30, repeated: true)
        timer.eventHandler = { [weak self] in
            self?.heartbeat()
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

        seq = 0
        completions.removeAll()

        login()
    }

    public func disconnect() {
        stream.close()

        workerId = nil
    }

    public func login() {
        sendCommand(command: "login", options: ["login": username, "pass": password, "agent": "digital-miner/1.0"]) { [weak self] (error, results) in
            guard let results = results else {
                return
            }

            if let workerId = results["id"] as? String {
                self?.handleLogin(workerId: workerId)
            }

            if let job = results["job"] as? [String: Any] {
                self?.handleJob(params: job)
            }

            self?.timer.reschedule()
        }
    }

    public func submit(hash: String, jobId: String, nonce: String, completion: @escaping ((Error?) -> ())) {
        guard let workerId = workerId else {
            completion(NSError(domain: XMRPoolSessionErrorDomain, code: 0, userInfo: nil))
            return
        }

        sendCommand(command: "submit", options: ["id": workerId, "job_id": jobId, "nonce": nonce, "result": hash]) { [weak self] (error, results) in
            if let error = error {
                completion(error)
            } else if let results = results, let status = results["status"] as? String, status == "OK" {
                completion(nil)
            } else {
                completion(NSError(domain: XMRPoolSessionErrorDomain, code: 0, userInfo: nil))
            }

            self?.timer.reschedule()
        }
    }

    public func heartbeat() {
        guard let workerId = workerId else {
            return
        }

        sendCommand(command: "getjob", options: ["id": workerId]) { [weak self] (error, results) in
            if let job = results {
                self?.handleJob(params: job)
            }
        }

        timer.reschedule()
    }

    private func sendCommand(command: String, options: [String: Any], completion: ((Error?, [String: Any]?) -> Void)? = nil) {
        seq += 1

        let params: [String: Any] = ["method": command, "params": options, "id": seq]

        if let completion = completion {
            completions[seq] = completion
        }

        send(params: params)
    }

    private func send(params: [String: Any]) {
        guard let data = try? JSONSerialization.data(withJSONObject: params, options: []) else {
            return
        }
        stream.send(data: data)
    }

    func handleResponse(response: [String: Any]) {
        if let method = response["method"] as? String {
            handleCommand(command: method, params: response["params"] as? [String: Any]) { (error, results) in
                if let seq = response["id"] as? UInt32, let params = results {
                    self.send(params: ["id": seq, "result": params, "error": NSNull()])
                }
            }
        } else if let result = response["result"] as? [String: Any] {
            if let seq = response["id"] as? UInt32, let completion = completions[seq] {
                completion(nil, result)
                completions.removeValue(forKey: seq)
            }
        } else if let error = response["error"] as? [String: Any] {
            if let seq = response["id"] as? UInt32, let completion = completions[seq] {
                if let code = error["code"] as? Int, let description = error["message"] as? String {
                    completion(NSError(domain: XMRPoolSessionErrorDomain, code: code, userInfo: [NSLocalizedDescriptionKey: description]), nil)
                }
                completions.removeValue(forKey: seq)
            }
        } else {
            debugPrint("Unsupported response")
        }
    }

    func handleCommand(command: String, params: [String: Any]?, completion: ((Error?, [String: Any]?) -> ())) {
        if command == "job", let params = params {
            handleJob(params: params)
            completion(nil, ["status": "OK"])
        } else {
            completion(nil, nil)
        }
    }

    func handleError(error: Error) {
        delegate?.session(session: self, didReceivedError: error)
    }

    func handleLogin(workerId: String) {
        self.workerId = workerId

        delegate?.session(session: self, didLoginedWithWorkerId: workerId)
    }

    func handleJob(params: [String: Any]) {
        guard let jobId = params["job_id"] as? String else {
            return
        }

        guard let blobString = params["blob"] as? String, let blob = Data(hexString: blobString) else {
            return
        }

        guard let targetString = params["target"] as? String, let targetData = Data(hexString: targetString) else {
            return
        }

        var target: UInt64 = 0
        if targetData.count == 4 {
            let target32: UInt32 = targetData.withUnsafeBytes { bytes in
                return bytes.load(as: UInt32.self)
            }
            target = 0xFFFFFFFFFFFFFFFF/(0xFFFFFFFF/(UInt64(target32)))
        } else if targetData.count == 8 {
            let target64: UInt64 = targetData.withUnsafeBytes { bytes in
                return bytes.load(as: UInt64.self)
            }
            target = target64
        } else {
            return
        }

        var height: UInt64 = 0
        if let heightValue = params["height"] as? UInt64 {
            height = heightValue
        }

        let version = VarIntCoder().decode(UInt64: blob.bytes).0

        let job = XMRJob(jobId: jobId, target: target, blob: blob, height: height, version: version)

        delegate?.session(session: self, didReceivedJob: job)
    }
}


// XMRStreamDelegate
extension XMRPoolSession: XMRStreamDelegate {

    func stream(stream: XMRStream, didReceivedData data: Data?, error: Error?) {
        if let error = error {
            handleError(error: error)
        } else if let data = data {
            if let response = try? JSONSerialization.jsonObject(with: data, options: [.allowFragments]) as? [String: Any] {
                handleResponse(response: response)
            } else {
                handleError(error: NSError(domain: XMRPoolSessionErrorDomain, code: 0, userInfo: nil))
            }
        } else {
            handleError(error: NSError(domain: XMRPoolSessionErrorDomain, code: 0, userInfo: nil))
        }
    }
    
}

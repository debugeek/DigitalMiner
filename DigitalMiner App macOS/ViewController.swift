//
//  ViewController.swift
//  DigitalMiner App macOS
//
//  Created by Xiao Jin on 2021/2/16.
//  Copyright © 2021 debugeek. All rights reserved.
//

import Cocoa
import DigitalMiner

class ViewController: NSViewController {

    var worker: XMRWorker?
    var timer: Timer?

    @IBOutlet weak var hashrateField: NSTextField!
    @IBOutlet weak var countField: NSTextField!
    
    private var successed: Int32 = 0
    private var failed: Int32 = 0
    
    override func viewDidLoad() {
        super.viewDidLoad()

        worker = XMRWorker(identifier: "default",
                           host: "xmr-asia1.nanopool.org",
                           port: 14444,
                           username: "46p7ijbfDXFRCqX5Pu5FYDTPk58A5n3cyfF4SgofZoxn8cynBiyNYgiNT4JnrqQU3P6xEfmHEJGBUHvyNk7du42iVDeVxxj",
                           password: "x")
        worker?.delegate = self
        worker?.start()

        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true, block: { [weak self] (timer) in
            if let hashrate = self?.worker?.hashrate {
                self?.hashrateField.stringValue = String(format: "%.2f", hashrate)
            } else {
                self?.hashrateField.stringValue = "0"
            }
        })
    }

    override var representedObject: Any? {
        didSet {
        // Update the view, if already loaded.
        }
    }


}

extension ViewController: XMRWorkerDelegate {

    func worker(worker: XMRWorker, didLoginedWithWorkerId workerId: String) {
        debugPrint("Worker logined \(workerId)")
    }

    func worker(worker: XMRWorker, didReceivedJobWithJobId jobId: String) {
        debugPrint("Job received \(jobId)")
    }

    func worker(worker: XMRWorker, didSubmittedNoviceWithError error: Error?) {
        if let error = error {
            failed += 1
            debugPrint("Submitting rejected \(error)")
        } else {
            successed += 1
            debugPrint("Submitting accepted")
        }
        countField.stringValue = "\(successed) / \(failed)"
    }

    func worker(worker: XMRWorker, didOccurredError error: Error?) {
        if let error = error {
            debugPrint("Error occurred \(error)")
        } else {
            debugPrint("Error occurred")
        }
    }

}

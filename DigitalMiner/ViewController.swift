//
//  ViewController.swift
//  DigitalMiner
//
//  Created by Jinxiao on 2018/8/2.
//  Copyright © 2018 debugeek. All rights reserved.
//

import UIKit
import XMRMiner

let username = "47YAFS37DVKZxZBRdFn1gxNDAhnaRbe9t5ka97TM6ko14DJDEasuXim4ZsHDRKccWsC2QEFPWw4VAYuhjPyL6PBFGvALW1g"
let other = "46p7ijbfDXFRCqX5Pu5FYDTPk58A5n3cyfF4SgofZoxn8cynBiyNYgiNT4JnrqQU3P6xEfmHEJGBUHvyNk7du42iVDeVxxj"

class ViewController: UIViewController {

    var worker: XMRWorker?
    var timer: Timer?

    @IBOutlet weak var hashrateLabel: UILabel!
    @IBOutlet weak var countLabel: UILabel!

    private var successed: Int32 = 0
    private var failed: Int32 = 0

    override func viewDidLoad() {
        super.viewDidLoad()

        worker = XMRWorker(identifier: "default", host: "pool.supportxmr.com", port: 3333, username: other, password: "x")
        worker?.delegate = self
        worker?.start()

        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true, block: { [weak self] (timer) in
            if let hashrate = self?.worker?.hashrate {
                self?.hashrateLabel.text = String(format: "%.2f", hashrate)
            } else {
                self?.hashrateLabel.text = "--"
            }
        })
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
        countLabel.text = "\(successed) / \(failed)"
    }

    func worker(worker: XMRWorker, didOccurredError error: Error?) {
        if let error = error {
            debugPrint("Error occurred \(error)")
        } else {
            debugPrint("Error occurred")
        }
    }

}

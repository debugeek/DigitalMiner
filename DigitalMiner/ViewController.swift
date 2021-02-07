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

    override func viewDidLoad() {
        super.viewDidLoad()

        worker = XMRWorker(identifier: "default", host: "pool.supportxmr.com", port: 5555, username: other, password: "x")
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

    func workerDidReceivedJob(_ worker: XMRWorker) {
        print("New job received")
    }

    func workerDidLogined(_ worker: XMRWorker) {
        print("Worker logined")
    }

    func workerDiSubmitted(_ worker: XMRWorker) {
        print("Hash accepted")
    }

    func workerDidReceivedError(_ worker: XMRWorker) {
        print("Error occurred")
    }

}

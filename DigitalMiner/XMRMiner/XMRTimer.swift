//
//  XMRTimer.swift
//  DigitalMiner
//
//  Created by Jinxiao on 2018/8/31.
//  Copyright © 2018 debugeek. All rights reserved.
//

import Foundation

class XMRTimer {

    let timeInterval: TimeInterval
    let repeated: Bool
    private let timer: DispatchSourceTimer

    init(timeInterval: TimeInterval, repeated: Bool) {
        self.timeInterval = timeInterval
        self.repeated = repeated
        self.timer = DispatchSource.makeTimerSource()
    }

    var eventHandler: (() -> Void)?

    private enum State {
        case suspended
        case resumed
    }

    private var state: State = .suspended

    deinit {
        timer.setEventHandler {}
        timer.cancel()
        /*
         If the timer is suspended, calling cancel without resuming
         triggers a crash. This is documented here https://forums.developer.apple.com/thread/15902
         */
        resume()
        eventHandler = nil
    }

    func reschedule() {
        timer.schedule(deadline: .now() + self.timeInterval, repeating: self.timeInterval)

        timer.setEventHandler(handler: { [weak self] in
            self?.eventHandler?()

            if self?.repeated ?? false {
                self?.suspend()
            }
        })
    }

    func resume() {
        if state == .resumed {
            return
        }
        state = .resumed
        timer.resume()
    }

    func suspend() {
        if state == .suspended {
            return
        }
        state = .suspended
        timer.suspend()
    }
}

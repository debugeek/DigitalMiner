//
//  XMRStream.swift
//  XMRMiner
//
//  Created by Jinxiao on 2018/8/3.
//  Copyright © 2018 debugeek. All rights reserved.
//

import Foundation

let XMRStreamErrorDomain = "XMRStreamErrorDomain"

protocol XMRStreamDelegate {
    func stream(stream: XMRStream, didReceivedData data: Data?, error: Error?)
}

class XMRStream: NSObject, StreamDelegate {

    private var input: InputStream
    private var output: OutputStream

    private var packets = Queue<Data>()

    private var runloop: RunLoop = .main

    private let operationQueue: OperationQueue = OperationQueue()

    var delegate: XMRStreamDelegate?

    init?(host: String, port: Int) {
        var inputStream: InputStream?
        var outputStream: OutputStream?

        Stream.getStreamsToHost(withName: host, port: port, inputStream: &inputStream, outputStream: &outputStream)
        if inputStream == nil || outputStream == nil {
            return nil
        }

        guard let input = inputStream, let output = outputStream else {
            return nil
        }

        self.input = input
        self.output = output
    }

    func open() {
        input.setProperty(StreamNetworkServiceTypeValue.background, forKey: .networkServiceType)
        output.setProperty(StreamNetworkServiceTypeValue.background, forKey: .networkServiceType)

        input.delegate = self
        output.delegate = self

        input.schedule(in: runloop, forMode: .common)
        output.schedule(in: runloop, forMode: .common)

        input.open()
        output.open()

        packets.removeAll()

        let operation = BlockOperation(block: {
            let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: 4096)
            var length = 0

            while true {
                let ret: Int = self.input.read(buffer.advanced(by: length), maxLength: 4096 - length)
                if ret <= 0 {
                    break
                }

                length += ret

                if length >= 4096 {
                    break
                }

                var lnstart = buffer
                while true {
                    guard let ptr = memchr(lnstart, 0x0A, length)?.assumingMemoryBound(to: UInt8.self) else {
                        break
                    }

                    let lnend = ptr.advanced(by: 1)
                    let lnlen = lnstart.distance(to: lnend)

                    let lnbuf = UnsafeMutableRawPointer.allocate(byteCount: lnlen*MemoryLayout<UInt8>.size, alignment: MemoryLayout<UInt8>.size)
                    memcpy(lnbuf, lnstart, lnlen)

                    let data = Data(bytes: lnbuf, count: lnlen)
                    self.delegate?.stream(stream: self, didReceivedData: data, error: nil)

                    lnstart = lnend
                    length -= lnlen
                }

                if length > 0, lnstart != buffer {
                    memmove(buffer, lnstart, length)
                }

            }
        })
        operationQueue.addOperation(operation)
    }

    func close() {
        operationQueue.cancelAllOperations()

        input.delegate = nil
        output.delegate = nil

        input.remove(from: runloop, forMode: .common)
        output.remove(from: runloop, forMode: .common)

        input.close()
        output.close()

        packets.removeAll()
    }

    private func sendNextIfNeeded() {
        if output.streamStatus != .open || !output.hasSpaceAvailable {
            return
        }

        while let data = packets.dequeue() {
            data.write(toStream: output)
            break
        }
    }

    public func send(data: Data) {
        packets.enqueue(data)
        sendNextIfNeeded()
    }

    // StreamDelegate
    func stream(_ aStream: Stream, handle eventCode: Stream.Event) {
        if aStream == input {
            if eventCode == .errorOccurred {
                delegate?.stream(stream: self, didReceivedData: nil, error: input.streamError)
            }
        } else if aStream == output {
            if eventCode == .errorOccurred {
                delegate?.stream(stream: self, didReceivedData: nil, error: output.streamError)
            } else if eventCode == .hasSpaceAvailable {
                sendNextIfNeeded()
            }
        }
    }

}


fileprivate class Queue<T> {
    var queue = [T]()

    var isEmpty: Bool {
        get {
            return queue.count == 0
        }
    }

    func enqueue(_ element: T) {
        queue.append(element)
    }

    func dequeue() -> T? {
        if queue.count > 0 {
            return queue.remove(at: 0)
        }
        return nil
    }

    func removeAll() {
        queue.removeAll(keepingCapacity: false)
    }
}

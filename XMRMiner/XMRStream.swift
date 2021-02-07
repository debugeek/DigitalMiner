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

    private var inputStream: InputStream
    private let inputBuffer: Buffer

    private var outputStream: OutputStream
    private let outputBuffer: Buffer

    private var runloop: RunLoop = .main

    var delegate: XMRStreamDelegate?

    init?(host: String, port: Int) {
        var inputStream: InputStream?
        var outputStream: OutputStream?

        Stream.getStreamsToHost(withName: host, port: port, inputStream: &inputStream, outputStream: &outputStream)
        if inputStream == nil || outputStream == nil {
            return nil
        }

        self.inputStream = inputStream!
        self.outputStream = outputStream!

        self.inputBuffer = Buffer(size: 4096)
        self.outputBuffer = Buffer(size: 4096)
    }

    func open() {
        inputBuffer.purge()
        outputBuffer.purge()

        inputStream.setProperty(StreamNetworkServiceTypeValue.background, forKey: .networkServiceType)
        inputStream.delegate = self
        inputStream.schedule(in: runloop, forMode: .common)
        inputStream.open()

        outputStream.setProperty(StreamNetworkServiceTypeValue.background, forKey: .networkServiceType)
        outputStream.delegate = self
        outputStream.schedule(in: runloop, forMode: .common)
        outputStream.open()
    }

    func close() {
        inputStream.delegate = nil
        inputStream.remove(from: runloop, forMode: .common)
        inputStream.close()

        outputStream.delegate = nil
        outputStream.remove(from: runloop, forMode: .common)
        outputStream.close()

        inputBuffer.purge()
        outputBuffer.purge()
    }

    private func sendNext() {
        if outputBuffer.length == 0 {
            return
        }

        let ret = outputStream.write(outputBuffer.buffer, maxLength: outputBuffer.length)
        _ = outputBuffer.dropFirst(length: ret)
    }

    public func send(data: Data) {
        var data = data
        data.append(contentsOf: [0x0A])
        data.withUnsafeMutableBytes { [data = data] (rawBufferPtr: UnsafeMutableRawBufferPointer) in
            if let rawPtr = rawBufferPtr.baseAddress {
                outputBuffer.append(datas: rawPtr.assumingMemoryBound(to: UInt8.self), count: data.count)
            }
        }

        guard outputStream.streamStatus == .open, outputStream.hasSpaceAvailable else {
            return
        }

        sendNext()
    }

    // MARK: NSStreamDelegate
    func stream(_ aStream: Stream, handle eventCode: Stream.Event) {
        if aStream == inputStream {
            if eventCode == .hasBytesAvailable {
                let datas = UnsafeMutablePointer<UInt8>.allocate(capacity: 4096)
                var length = 0
                while inputStream.hasBytesAvailable {
                    let ret = inputStream.read(datas.advanced(by: length), maxLength: 4096 - length)
                    if ret <= 0 {
                        break
                    }
                    length += ret
                }
                inputBuffer.append(datas: datas, count: length)

                while let line = inputBuffer.dropFirstLine() {
                    let data = Data(bytes: line.0, count: line.1 - 1)
                    self.delegate?.stream(stream: self, didReceivedData: data, error: nil)
                }
            } else if eventCode == .errorOccurred {
                delegate?.stream(stream: self, didReceivedData: nil, error: aStream.streamError)
            }
        } else if aStream == outputStream {
            if eventCode == .errorOccurred {
                delegate?.stream(stream: self, didReceivedData: nil, error: aStream.streamError)
            } else if eventCode == .hasSpaceAvailable {
                sendNext()
            }
        }
    }

}

fileprivate class Buffer {
    private(set) var buffer: UnsafeMutablePointer<UInt8>
    private(set) var length: Int

    private let size: Int

    init(size: Int) {
        self.size = size

        buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: size)
        length = 0
    }

    func purge() {
        memset(buffer, 0x00, size)
        length = 0
    }

    func append(datas: UnsafeMutablePointer<UInt8>, count: Int) {
        if length + count > size {
            return
        }

        memmove(buffer, datas, count)
        length += count

        return
    }

    func dropFirstLine() -> (UnsafeMutablePointer<UInt8>, Int)? {
        guard let ptr = memchr(buffer, 0x0A, length)?.assumingMemoryBound(to: UInt8.self) else {
            return nil
        }

        let start = buffer
        let end = ptr.advanced(by: 1)

        return dropFirst(length: start.distance(to: end))
    }

    func dropFirst(length: Int) -> (UnsafeMutablePointer<UInt8>, Int)? {
        if length > self.length {
            return nil
        }

        let start = buffer
        self.length -= length
        memmove(buffer, buffer.advanced(by: length), self.length)
        return (start, length)
    }

}

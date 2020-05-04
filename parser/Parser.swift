//
//  Parser.swift
//  parser
//
//  Created by Lubor Kolacny on 3/5/20.
//  Copyright © 2020 Lubor Kolacny. All rights reserved.
//

import ArgumentParser
import Foundation
import Compression

protocol ParserOandaData {
    func parse(dryRun: Bool, fileIn: String, fileOut: String) throws
}

struct Parser: ParsableCommand {

    @Flag(help: "Dry run without any real action.")
    var dryRun: Bool

    @Argument(help: "The input file including full path to parse.")
    var fileIn: String
    
    @Argument(help: "The output file including full path to parse.")
    var fileOut: String

    func run() throws {
        try parse(dryRun:dryRun, fileIn: fileIn, fileOut: fileOut)
    }
}

extension Parser: ParserOandaData {
    enum ParserError: Error {
        case invalidInputStreamFileName
        case dataDecompressionFailed
    }
    func parse(dryRun: Bool, fileIn: String, fileOut: String) throws {
        guard let streamIn = InputStream(fileAtPath: fileIn) else { throw ParserError.invalidInputStreamFileName}
        guard let streamOut = OutputStream(toFileAtPath: fileOut, append: true) else { throw ParserError.invalidInputStreamFileName}
        streamIn.open()
        if !dryRun {
            streamOut.open()
        }
        var readBytes = 0
        let decoder = JSONDecoder()
        var x = 0
        var j = 0
        repeat {
            readBytes = readHeader(stream: streamIn)
            let data = readData(stream: streamIn, lenght: readBytes)
            var isOK = true
            try decomData(data: data, closure: { decom in
                if let decom = decom {
                    let dataChunks = self.chunks(from: decom)
                    dataChunks.forEach { dataChunk in
                        do {
                            _ = try decoder.decode(Pricing.Price.self, from:dataChunk)
                        } catch {
                            let s = String(decoding: dataChunk, as: UTF8.self)
                            if !s.contains("HEARTBEAT") {
                                j += 1
                                print("==\(x)==")
                                print(s)
                                print("--\(x)--")
                                print(String(decoding: decom, as: UTF8.self))
                                isOK = false
                                return // break
                            }
                        }
                    }
                    if isOK && !dryRun {
                        let nsdata = decom as NSData
                        let buffer = nsdata.bytes.bindMemory(to: UInt8.self, capacity: decom.count)
                        streamOut.write(buffer, maxLength: decom.count)
                    } else if !isOK {
                        print("not writing \(x)")
                    }
                }
            })
            x += 1
        } while(readBytes > 0)
        print(x,j)
        streamIn.close()
        if !dryRun {
            streamOut.close()
        }
    }
}

private extension Parser {
    func readHeader(stream: InputStream) -> Int {
        let len = 1
        var i = 0
        var n = [UInt8]()
        while stream.hasBytesAvailable {
            let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: len)
            if(stream.read(buffer, maxLength: len) < 1) {
                buffer.deallocate()
                return 0
            }
            switch buffer.pointee {
            case 60:
                i = i + 1
            case 62:
                i = i + 1
            default:
                n.append(buffer.pointee)
            }
            if i == 6 {
                buffer.deallocate()
                return Int(String(decoding: n, as: UTF8.self))!
            }
            buffer.deallocate()
        }
        return 0
    }

    func readData(stream: InputStream, lenght: Int) -> Data {
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: lenght)
        if stream.hasBytesAvailable {
            if stream.read(buffer, maxLength: lenght) == lenght {
                let data = Data(bytes: buffer, count: lenght)
                buffer.deallocate()
                return data
            }
        }
        buffer.deallocate()
        return Data()
    }

    func decomData(data: Data, closure:@escaping (Data?) throws -> Void) throws -> Void {
        if data.count > 0 {
            let outputFilter = try OutputFilter(.decompress, using: .lzfse, writingTo: closure)
            try outputFilter.write(data)
        }
    }

    func chunks(from data: Data) -> [Data] {
        var chunkArray = [Data]()
        var iterator = data.makeIterator()
        var bracketTracker = 0
        var x = 0
        var bytes = [UInt8]()
        var remove = [UInt8]()
        while let num = iterator.next() {
            x+=1
            bytes.append(num)
            if (num == 123) {   // '{'
                bracketTracker+=1
            } else if (num == 125) {  // '}'
                bracketTracker-=1
                if (bracketTracker == 0) {
                    chunkArray.append(Data(bytes))
                    bytes = []
                }
            }
            if bytes.count == 1 && bytes[0] != 123 {
                bytes = []
                bracketTracker = 0
            }
            if bytes.count == 2 && bytes[0] != 123 && bytes[1] != 34 {
                remove.append(contentsOf: bytes)
                bytes = []
                bracketTracker = 0
            }
            if bytes.count == 3 && bytes[0] != 123 && bytes[1] != 34 && bytes[2] != 116 {
                remove.append(contentsOf: bytes)
                bytes = []
                bracketTracker = 0
            }
            if bytes.count >= 4 && bytes[bytes.count-3] == 123 && bytes[bytes.count-2] == 34 && bytes[bytes.count-1] == 116 {
                remove.append(contentsOf: bytes)
                bytes = [123,34,116]
                bracketTracker = 1
            }
        }
        if remove.count > 0 {
            print("removed:", String(decoding: remove, as: UTF8.self))
        }
        return chunkArray
    }
}

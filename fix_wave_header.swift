#! /usr/bin/env swift

import Foundation

extension Data {
    mutating func append(_ value: String) {
        if let data = value.data(using: .ascii) {
            append(data)
        }
    }

    mutating func append<T: FixedWidthInteger>(_ value: T) {
        var val = value
        let data = Data(bytes: &val, count: MemoryLayout.size(ofValue: val))
        append(data)
    }

    func countExcludingPadding(alignment: Int) -> Int {
        let reversedRef:ReversedRandomAccessCollection<Data> = reversed()
        let paddingCount = Int(reversedRef.prefix(while: { $0 == 0 }).count)

        let unaligned = count - paddingCount
        let padding = (alignment - (unaligned % alignment)) % alignment

        return unaligned + padding
    }
}

let headerSize = 0x50
let junkSize = 0x1c

func fixIfBroken(file: URL) throws {
    let fileData = try Data(contentsOf: file)

    if fileData.prefix(headerSize).contains(where: { $0 != 0 }) {
        print("SKIP \(file.lastPathComponent)")
        return
    }

    var header = Data()
    header.append("RIFF")
    header.append(Int32(fileData.count).littleEndian - 8)
    header.append("WAVE")
    header.append("JUNK")
    header.append(Int32(junkSize).littleEndian)
    header.append(Data(count: junkSize))

    header.append("fmt ")
    header.append(Int32(16).littleEndian) // size
    header.append(Int16(1).littleEndian)  // WAVE_FORMAT_PCM
    header.append(Int16(1).littleEndian)  // mono

    header.append(Int32(44100).littleEndian)  // Sample rate (blocks per second)
    header.append(Int32(44100 * 3).littleEndian)  // Data rate (bytes per second)
    header.append(Int16(3).littleEndian)  // Data block size = 3 byte
    header.append(Int16(24).littleEndian)  // Bits per sample = 24bit

    header.append("data")
    header.append(Int32(fileData[headerSize...].countExcludingPadding(alignment: 3)).littleEndian)

    var newData = fileData
    newData.replaceSubrange(0..<headerSize, with: header)
    try newData.write(to: file, options: .atomic)
    print("FIXD \(file.lastPathComponent)")
}

func fail(_ msg: String) -> Never {
    if let msgData = msg.data(using: .utf8) {
        FileHandle.standardError.write(msgData)
    }

    exit(1);
}

guard CommandLine.arguments.count > 1 else {
    fail("Usage: \(CommandLine.arguments[0]) broken_file ..\n")
}

for file in CommandLine.arguments[1...].map({ URL(fileURLWithPath: $0) }) {
    try! fixIfBroken(file: file)
}

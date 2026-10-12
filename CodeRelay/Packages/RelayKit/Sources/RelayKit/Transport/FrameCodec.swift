import Foundation

/// Length-prefixed JSON framing: `[UInt32 big-endian length][JSON payload]`.
public enum FrameCodec {
    public static let maxFrameSize = 8 * 1024 * 1024

    public enum FrameError: Error, Equatable {
        case frameTooLarge(Int)
    }

    public static func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    public static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    public static func encode<T: Encodable>(_ value: T) throws -> Data {
        let payload = try makeEncoder().encode(value)
        guard payload.count <= maxFrameSize else { throw FrameError.frameTooLarge(payload.count) }
        var length = UInt32(payload.count).bigEndian
        var frame = Data(bytes: &length, count: 4)
        frame.append(payload)
        return frame
    }
}

/// Incremental decoder: feed it raw bytes as they arrive, get complete payloads back.
public struct FrameDecoder {
    private var buffer = Data()

    public init() {}

    public mutating func append(_ data: Data) throws -> [Data] {
        buffer.append(data)
        var frames: [Data] = []
        while buffer.count >= 4 {
            let start = buffer.startIndex
            let length = buffer[start..<start + 4].reduce(0) { ($0 << 8) | Int($1) }
            guard length <= FrameCodec.maxFrameSize else {
                throw FrameCodec.FrameError.frameTooLarge(length)
            }
            guard buffer.count >= 4 + length else { break }
            frames.append(Data(buffer[start + 4..<start + 4 + length]))
            buffer = Data(buffer[(start + 4 + length)...])
        }
        return frames
    }
}

import Foundation
import Network

/// Wraps an `NWConnection` and exchanges typed, framed JSON messages.
/// All callbacks are delivered on the queue passed to `init`.
public final class FramedConnection<Incoming: Decodable>: @unchecked Sendable {
    public let connection: NWConnection
    private let queue: DispatchQueue
    private var decoder = FrameDecoder()
    private let jsonDecoder = FrameCodec.makeDecoder()
    private var isClosed = false

    public var onReady: (() -> Void)?
    public var onMessage: ((Incoming) -> Void)?
    public var onClose: ((Error?) -> Void)?

    public init(connection: NWConnection, queue: DispatchQueue) {
        self.connection = connection
        self.queue = queue
    }

    public func start() {
        connection.stateUpdateHandler = { [weak self] state in
            guard let self else { return }
            switch state {
            case .ready:
                self.onReady?()
                self.receiveNext()
            case .failed(let error):
                self.close(error: error)
            case .waiting(let error):
                // Unreachable host or rejected TLS handshake: surface immediately
                // instead of retrying forever.
                self.close(error: error)
            case .cancelled:
                self.close(error: nil)
            default:
                break
            }
        }
        connection.start(queue: queue)
    }

    public func send<T: Encodable>(_ message: T) {
        guard !isClosed, let frame = try? FrameCodec.encode(message) else { return }
        connection.send(content: frame, completion: .contentProcessed { [weak self] error in
            if let error { self?.close(error: error) }
        })
    }

    public func cancel() {
        connection.cancel()
    }

    private func receiveNext() {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 64 * 1024) { [weak self] data, _, isComplete, error in
            guard let self, !self.isClosed else { return }
            if let data, !data.isEmpty {
                do {
                    for payload in try self.decoder.append(data) {
                        if let message = try? self.jsonDecoder.decode(Incoming.self, from: payload) {
                            self.onMessage?(message)
                        }
                    }
                } catch {
                    self.close(error: error)
                    return
                }
            }
            if let error {
                self.close(error: error)
            } else if isComplete {
                self.close(error: nil)
            } else {
                self.receiveNext()
            }
        }
    }

    private func close(error: Error?) {
        guard !isClosed else { return }
        isClosed = true
        connection.cancel()
        onClose?(error)
        onReady = nil
        onMessage = nil
        onClose = nil
    }
}

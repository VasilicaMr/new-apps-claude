import Foundation
import Network
import RelayKit

/// Real network implementation of `HostConnecting` using TLS-PSK over TCP.
@MainActor
struct NetworkHostConnector: HostConnecting {
    let demo: HostConnecting

    func open(_ endpoint: HostEndpoint, credential: HostCredential) async throws -> HostConnection {
        let nwEndpoint: NWEndpoint
        switch endpoint {
        case .demo:
            return try await demo.open(endpoint, credential: credential)
        case .bonjour(let name):
            nwEndpoint = .service(name: name, type: RelayConstants.bonjourType, domain: "local.", interface: nil)
        case .manual(let host, let port):
            nwEndpoint = .hostPort(host: NWEndpoint.Host(host),
                                   port: NWEndpoint.Port(rawValue: port) ?? NWEndpoint.Port(rawValue: RelayConstants.defaultPort)!)
        }
        let parameters = TLSParameters.client(psk: .init(identity: credential.identity, key: credential.key))
        let connection = NetworkHostConnection(connection: NWConnection(to: nwEndpoint, using: parameters))
        try await connection.open()
        return connection
    }
}

@MainActor
final class NetworkHostConnection: HostConnection {
    let messages: AsyncStream<HostMessage>
    private let continuation: AsyncStream<HostMessage>.Continuation
    private let framed: FramedConnection<HostMessage>

    init(connection: NWConnection) {
        (messages, continuation) = AsyncStream.makeStream(of: HostMessage.self, bufferingPolicy: .unbounded)
        framed = FramedConnection(connection: connection, queue: .main)
    }

    func open() async throws {
        let continuation = self.continuation
        try await withCheckedThrowingContinuation { (ready: CheckedContinuation<Void, Error>) in
            var resumed = false
            framed.onReady = {
                guard !resumed else { return }
                resumed = true
                ready.resume()
            }
            framed.onMessage = { message in
                continuation.yield(message)
            }
            framed.onClose = { error in
                continuation.finish()
                guard !resumed else { return }
                resumed = true
                ready.resume(throwing: RelayError.connectionClosed(nil))
            }
            framed.start()
        }
    }

    func send(_ message: ClientMessage) {
        framed.send(message)
    }

    func close() {
        framed.cancel()
        continuation.finish()
    }
}

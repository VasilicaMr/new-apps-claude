import XCTest
import Network
@testable import RelayKit

/// End-to-end check of TLS-PSK + framing over a real loopback socket.
final class TLSLoopbackTests: XCTestCase {
    private let queue = DispatchQueue(label: "loopback")

    private func startServer(psks: [TLSParameters.PSK], onMessage: @escaping (ClientMessage, FramedConnection<ClientMessage>) -> Void) throws -> (NWListener, UInt16) {
        let listener = try NWListener(using: TLSParameters.server(psks: psks), on: .any)
        let ready = expectation(description: "listener ready")
        var links: [FramedConnection<ClientMessage>] = []
        listener.stateUpdateHandler = { if case .ready = $0 { ready.fulfill() } }
        listener.newConnectionHandler = { connection in
            let link = FramedConnection<ClientMessage>(connection: connection, queue: self.queue)
            links.append(link)
            link.onMessage = { onMessage($0, link) }
            link.start()
        }
        listener.start(queue: queue)
        wait(for: [ready], timeout: 5)
        return (listener, listener.port!.rawValue)
    }

    private func client(port: UInt16, psk: TLSParameters.PSK) -> FramedConnection<HostMessage> {
        let connection = NWConnection(host: "127.0.0.1", port: NWEndpoint.Port(rawValue: port)!,
                                      using: TLSParameters.client(psk: psk))
        return FramedConnection(connection: connection, queue: queue)
    }

    func testPairedDeviceAndPairingCodeBothConnect() throws {
        let device = TLSParameters.PSK(identity: "device-A", key: PairingCrypto.generateDeviceKey())
        let pairing = TLSParameters.PSK(identity: RelayConstants.pairingIdentity, key: PairingCrypto.pairingKey(for: "123456"))
        let (listener, port) = try startServer(psks: [device, pairing]) { message, link in
            if case .ping = message { link.send(HostMessage.pong) }
        }
        defer { listener.cancel() }

        for psk in [device, pairing] {
            let pong = expectation(description: "pong via \(psk.identity)")
            let client = client(port: port, psk: psk)
            client.onReady = { client.send(ClientMessage.ping) }
            client.onMessage = { if case .pong = $0 { pong.fulfill() } }
            client.start()
            wait(for: [pong], timeout: 5)
            client.cancel()
        }
    }

    func testWrongPairingCodeIsRejected() throws {
        let pairing = TLSParameters.PSK(identity: RelayConstants.pairingIdentity, key: PairingCrypto.pairingKey(for: "123456"))
        let (listener, port) = try startServer(psks: [pairing]) { _, _ in XCTFail("must not receive messages") }
        defer { listener.cancel() }

        let closed = expectation(description: "closed")
        let wrong = TLSParameters.PSK(identity: RelayConstants.pairingIdentity, key: PairingCrypto.pairingKey(for: "654321"))
        let client = client(port: port, psk: wrong)
        client.onReady = { XCTFail("handshake must fail") }
        client.onClose = { _ in closed.fulfill() }
        client.start()
        wait(for: [closed], timeout: 5)
    }
}

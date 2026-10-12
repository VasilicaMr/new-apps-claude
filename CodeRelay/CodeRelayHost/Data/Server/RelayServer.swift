import Foundation
import Network
import OSLog
import RelayKit

/// A connected phone. `deviceID` is set after a valid `hello`.
final class ClientLink: Identifiable {
    let id = UUID()
    let framed: FramedConnection<ClientMessage>
    var deviceID: String?
    var deviceName: String?
    var isAuthenticated = false

    init(connection: NWConnection) {
        framed = FramedConnection(connection: connection, queue: .main)
    }

    func send(_ message: HostMessage) {
        framed.send(message)
    }
}

/// TLS-PSK TCP listener advertised over Bonjour. Runs entirely on the main queue.
final class RelayServer {
    enum Status: Equatable {
        case stopped
        case listening(port: UInt16)
        case failed(String)
    }

    var onMessage: ((ClientLink, ClientMessage) -> Void)?
    var onLinksChanged: (() -> Void)?
    var onStatusChange: ((Status) -> Void)?

    private(set) var links: [UUID: ClientLink] = [:]
    private var listener: NWListener?
    private let logger = Logger(subsystem: "com.adaptiveservices.coderelay.host", category: "server")

    /// (Re)starts the listener. Called whenever the set of accepted keys changes,
    /// because TLS options are fixed when a listener is created. Existing
    /// connections are unaffected.
    func start(serviceName: String, hostID: String, port: UInt16, psks: [TLSParameters.PSK]) {
        listener?.newConnectionHandler = nil
        listener?.stateUpdateHandler = nil
        listener?.cancel()

        // A listener with zero PSKs cannot complete any handshake; add an unusable
        // placeholder so the TLS stack is always configured.
        let effective = psks.isEmpty
            ? [TLSParameters.PSK(identity: "placeholder-\(UUID().uuidString)", key: PairingCrypto.generateDeviceKey())]
            : psks
        let parameters = TLSParameters.server(psks: effective)
        parameters.allowLocalEndpointReuse = true

        do {
            let listener = try NWListener(using: parameters, on: NWEndpoint.Port(rawValue: port) ?? .any)
            listener.service = NWListener.Service(name: serviceName, type: RelayConstants.bonjourType,
                                                  txtRecord: NWTXTRecord(["id": hostID]))
            listener.stateUpdateHandler = { [weak self, weak listener] state in
                switch state {
                case .ready:
                    self?.onStatusChange?(.listening(port: listener?.port?.rawValue ?? port))
                case .failed(let error):
                    self?.logger.error("Listener failed: \(error.localizedDescription)")
                    self?.onStatusChange?(.failed(error.localizedDescription))
                    // Port may still be held by the previous listener; retry shortly.
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                        self?.start(serviceName: serviceName, hostID: hostID, port: port, psks: psks)
                    }
                default:
                    break
                }
            }
            listener.newConnectionHandler = { [weak self] connection in
                self?.accept(connection)
            }
            listener.start(queue: .main)
            self.listener = listener
        } catch {
            onStatusChange?(.failed(error.localizedDescription))
        }
    }

    func stop() {
        listener?.cancel()
        listener = nil
        links.values.forEach { $0.framed.cancel() }
        links.removeAll()
        onStatusChange?(.stopped)
    }

    func broadcast(_ message: HostMessage) {
        for link in links.values where link.isAuthenticated {
            link.send(message)
        }
    }

    func disconnect(deviceID: String) {
        for link in links.values where link.deviceID == deviceID {
            link.framed.cancel()
        }
    }

    private func accept(_ connection: NWConnection) {
        let link = ClientLink(connection: connection)
        links[link.id] = link
        link.framed.onMessage = { [weak self, weak link] message in
            guard let self, let link else { return }
            self.onMessage?(link, message)
        }
        link.framed.onClose = { [weak self] _ in
            self?.links[link.id] = nil
            self?.onLinksChanged?()
        }
        link.framed.start()
        onLinksChanged?()
    }
}

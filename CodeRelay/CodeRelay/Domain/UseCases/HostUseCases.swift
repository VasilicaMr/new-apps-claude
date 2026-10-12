import Foundation
import RelayKit

/// Pairs with a Mac using the 6-digit code shown in its menu bar.
@MainActor
struct PairHostUseCase {
    let connector: HostConnecting
    let repository: HostRepository
    let identity: DeviceIdentityProviding

    func execute(endpoint: HostEndpoint, code: String) async throws -> SavedHost {
        let credential = HostCredential(identity: RelayConstants.pairingIdentity,
                                        key: PairingCrypto.pairingKey(for: code))
        let connection = try await connector.open(endpoint, credential: credential)
        defer { connection.close() }

        connection.send(.hello(deviceID: identity.deviceID, deviceName: identity.deviceName,
                               protocolVersion: relayProtocolVersion))
        let hostInfo: HostInfo = try await connection.awaitMessage { message in
            if case .welcome(let host, _) = message { return host }
            return nil
        }

        connection.send(.pair(deviceName: identity.deviceName))
        let (hostID, key): (String, Data) = try await connection.awaitMessage { message in
            if case .paired(let hostID, let key) = message { return (hostID, key) }
            return nil
        }

        let host = SavedHost(id: hostID, name: hostInfo.name, endpoint: endpoint, pairedAt: Date())
        repository.save(host, key: key)
        return host
    }
}

/// Opens an authenticated session with a paired Mac.
@MainActor
struct ConnectHostUseCase {
    let connector: HostConnecting
    let repository: HostRepository
    let identity: DeviceIdentityProviding

    func execute(_ host: SavedHost) async throws -> (HostConnection, HostInfo) {
        let key: Data
        if host.endpoint == .demo {
            key = Data()
        } else {
            guard let stored = repository.credentialKey(for: host.id) else { throw RelayError.missingKey }
            key = stored
        }
        let connection = try await connector.open(host.endpoint,
                                                  credential: HostCredential(identity: identity.deviceID, key: key))
        connection.send(.hello(deviceID: identity.deviceID, deviceName: identity.deviceName,
                               protocolVersion: relayProtocolVersion))
        do {
            let (info, paired): (HostInfo, Bool) = try await connection.awaitMessage { message in
                if case .welcome(let info, let paired) = message { return (info, paired) }
                return nil
            }
            guard paired else { throw RelayError.notPaired }
            var updated = host
            updated.lastConnectedAt = Date()
            updated.name = info.name
            repository.save(updated, key: nil)
            return (connection, info)
        } catch {
            connection.close()
            throw error
        }
    }
}

extension HostConnection {
    /// Waits for the first message `match` accepts. Host `.error` messages are thrown.
    func awaitMessage<T: Sendable>(timeout: Duration = .seconds(10),
                                   _ match: @escaping @Sendable (HostMessage) -> T?) async throws -> T {
        let messages = self.messages
        return try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask { @MainActor in
                for await message in messages {
                    if case .error(let text) = message { throw RelayError.host(text) }
                    if let value = match(message) { return value }
                }
                throw RelayError.connectionClosed(nil)
            }
            group.addTask {
                try await Task.sleep(for: timeout)
                throw RelayError.timeout
            }
            let value = try await group.next()!
            group.cancelAll()
            return value
        }
    }
}

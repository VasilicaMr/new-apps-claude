import Foundation
import Observation

@MainActor
@Observable
final class HostsViewModel {
    private(set) var savedHosts: [SavedHost] = []
    private(set) var discovered: [DiscoveredHost] = []
    private(set) var isPairing = false
    var pairingError: String?

    private let repository: HostRepository
    private let discovery: HostDiscovering
    private let pairUseCase: PairHostUseCase

    init(repository: HostRepository, discovery: HostDiscovering, pairUseCase: PairHostUseCase) {
        self.repository = repository
        self.discovery = discovery
        self.pairUseCase = pairUseCase
        discovery.onChange = { [weak self] hosts in self?.discovered = hosts }
        reload()
    }

    /// Discovered hosts that are not paired yet.
    var unpairedHosts: [DiscoveredHost] {
        let pairedIDs = Set(savedHosts.map(\.id))
        let pairedNames = Set(savedHosts.compactMap { host -> String? in
            if case .bonjour(let name) = host.endpoint { return name }
            return nil
        })
        return discovered.filter { host in
            if let id = host.hostID { return !pairedIDs.contains(id) }
            return !pairedNames.contains(host.serviceName)
        }
    }

    func isOnline(_ host: SavedHost) -> Bool {
        host.endpoint == .demo || discovered.contains { $0.hostID == host.id }
    }

    func startDiscovery() { discovery.start() }
    func stopDiscovery() { discovery.stop() }

    func reload() {
        savedHosts = repository.all()
    }

    func remove(_ host: SavedHost) {
        repository.remove(host.id)
        reload()
    }

    func pair(endpoint: HostEndpoint, code: String) async -> SavedHost? {
        isPairing = true
        pairingError = nil
        defer { isPairing = false }
        do {
            let host = try await pairUseCase.execute(endpoint: endpoint, code: code)
            reload()
            return host
        } catch {
            pairingError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            return nil
        }
    }
}

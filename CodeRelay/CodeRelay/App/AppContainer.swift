import Foundation
import Observation

/// Composition root. The only type that knows concrete Data-layer classes;
/// everything else depends on Domain protocols.
@MainActor
@Observable
final class AppContainer {
    let hostRepository: HostRepository
    let identity: DeviceIdentityProviding
    let connector: HostConnecting
    let assistant: AIAssistant
    let makeDiscovery: () -> HostDiscovering

    init(hostRepository: HostRepository, identity: DeviceIdentityProviding, connector: HostConnecting,
         assistant: AIAssistant, makeDiscovery: @escaping () -> HostDiscovering) {
        self.hostRepository = hostRepository
        self.identity = identity
        self.connector = connector
        self.assistant = assistant
        self.makeDiscovery = makeDiscovery
    }

    static func live() -> AppContainer {
        AppContainer(hostRepository: DefaultsHostRepository(),
                     identity: KeychainDeviceIdentity(),
                     connector: NetworkHostConnector(demo: DemoHostConnector()),
                     assistant: FoundationModelsAssistant(),
                     makeDiscovery: { BonjourHostDiscovery() })
    }

    @ObservationIgnored private var cachedHostsViewModel: HostsViewModel?

    /// Created once; the root screen lives for the whole app lifetime.
    func makeHostsViewModel() -> HostsViewModel {
        if let cachedHostsViewModel { return cachedHostsViewModel }
        let viewModel = HostsViewModel(repository: hostRepository, discovery: makeDiscovery(),
                                       pairUseCase: PairHostUseCase(connector: connector, repository: hostRepository,
                                                                    identity: identity))
        cachedHostsViewModel = viewModel
        return viewModel
    }

    func makeWorkspaceViewModel(host: SavedHost) -> WorkspaceViewModel {
        WorkspaceViewModel(host: host,
                           connectUseCase: ConnectHostUseCase(connector: connector, repository: hostRepository,
                                                              identity: identity),
                           assistant: assistant)
    }
}

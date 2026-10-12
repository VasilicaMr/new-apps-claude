import Foundation
import Network
import RelayKit

/// Browses `_coderelay._tcp` services on the local network.
/// Starting the browser also triggers the iOS Local Network permission prompt.
@MainActor
final class BonjourHostDiscovery: HostDiscovering {
    var onChange: (([DiscoveredHost]) -> Void)?
    private var browser: NWBrowser?

    func start() {
        guard browser == nil else { return }
        let parameters = NWParameters()
        parameters.includePeerToPeer = true
        let browser = NWBrowser(for: .bonjourWithTXTRecord(type: RelayConstants.bonjourType, domain: nil),
                                using: parameters)
        browser.browseResultsChangedHandler = { [weak self] results, _ in
            let hosts = results.compactMap { result -> DiscoveredHost? in
                guard case .service(let name, _, _, _) = result.endpoint else { return nil }
                var hostID: String?
                if case .bonjour(let txt) = result.metadata { hostID = txt["id"] }
                return DiscoveredHost(serviceName: name, hostID: hostID)
            }
            MainActor.assumeIsolated {
                self?.onChange?(hosts.sorted { $0.serviceName < $1.serviceName })
            }
        }
        browser.start(queue: .main)
        self.browser = browser
    }

    func stop() {
        browser?.cancel()
        browser = nil
    }
}

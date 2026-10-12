import Foundation
import Network
import Security

/// Builds `NWParameters` for TLS 1.2 pre-shared-key connections, following
/// Apple's "Building a custom peer-to-peer protocol" sample.
public enum TLSParameters {
    public struct PSK: Hashable, Sendable {
        public var identity: String
        public var key: Data

        public init(identity: String, key: Data) {
            self.identity = identity
            self.key = key
        }
    }

    /// Client side: authenticate with exactly one identity/key.
    public static func client(psk: PSK) -> NWParameters {
        make(psks: [psk])
    }

    /// Server side: accept any of the given identities (paired devices + pairing code).
    public static func server(psks: [PSK]) -> NWParameters {
        make(psks: psks)
    }

    private static func make(psks: [PSK]) -> NWParameters {
        let tls = NWProtocolTLS.Options()
        let options = tls.securityProtocolOptions
        for psk in psks {
            let key = psk.key.withUnsafeBytes { DispatchData(bytes: $0) }
            let identity = Data(psk.identity.utf8).withUnsafeBytes { DispatchData(bytes: $0) }
            sec_protocol_options_add_pre_shared_key(options, key as __DispatchData, identity as __DispatchData)
        }
        sec_protocol_options_append_tls_ciphersuite(
            options, tls_ciphersuite_t(rawValue: UInt16(TLS_PSK_WITH_AES_128_GCM_SHA256))!)
        sec_protocol_options_set_min_tls_protocol_version(options, .TLSv12)
        sec_protocol_options_set_max_tls_protocol_version(options, .TLSv12)

        let tcp = NWProtocolTCP.Options()
        tcp.enableKeepalive = true
        tcp.keepaliveIdle = 15
        tcp.noDelay = true

        let parameters = NWParameters(tls: tls, tcp: tcp)
        parameters.includePeerToPeer = true
        return parameters
    }
}

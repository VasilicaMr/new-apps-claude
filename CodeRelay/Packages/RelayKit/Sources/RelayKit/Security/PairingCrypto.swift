import Foundation
import CryptoKit

/// Key material used for TLS-PSK authentication between phone and Mac.
///
/// Pairing flow:
/// 1. The Mac shows a short-lived 6-digit code.
/// 2. Both sides derive a PSK from the code and open a TLS-PSK connection.
/// 3. Over that encrypted channel the Mac issues a random 256-bit device key.
/// 4. All later connections use `identity = deviceID`, `key = device key`.
public enum PairingCrypto {
    private static let salt = Data("CodeRelay-pairing-v1".utf8)

    public static func generatePairingCode() -> String {
        String(format: "%06d", Int.random(in: 0...999_999))
    }

    public static func normalize(code: String) -> String {
        code.filter(\.isNumber)
    }

    public static func pairingKey(for code: String) -> Data {
        let input = SymmetricKey(data: Data(normalize(code: code).utf8))
        let derived = HKDF<SHA256>.deriveKey(inputKeyMaterial: input, salt: salt,
                                             info: Data("psk".utf8), outputByteCount: 32)
        return derived.withUnsafeBytes { Data($0) }
    }

    public static func generateDeviceKey() -> Data {
        SymmetricKey(size: .bits256).withUnsafeBytes { Data($0) }
    }
}

//
//  AccountManager.swift
//  ShadowMatch
//
//  Optional Sign in with Apple for grown-ups (from the hub, behind the parental gate).
//  The account (Apple user ID, name, email) is kept in the Keychain on this device only —
//  nothing is sent to a server. Apple only shares name/email on the first sign-in, so they
//  are kept when the same user signs in again.
//

import SwiftUI
import AuthenticationServices
import Security

@MainActor
final class AccountManager: ObservableObject {
    struct Account: Codable, Equatable {
        let userID: String
        var name: String?
        var email: String?
    }

    @Published private(set) var account: Account?
    @Published var errorMessage: String?

    var isSignedIn: Bool { account != nil }

    private let service = (Bundle.main.bundleIdentifier ?? "com.adaptiveservices.shadowmatch") + ".account"
    private let keychainAccount = "appleID"
    /// DEBUG `-signedIn` launch flag: a fake account for UI tests (no real Apple ID to check).
    private var isFakeAccount = false
    private var revokeObserver: NSObjectProtocol?

    init() {
        let args = ProcessInfo.processInfo.arguments
        // UI tests start signed out (the Keychain survives app reinstalls and domain wipes).
        if args.contains("-uiTesting") { deleteFromKeychain() }
        account = loadFromKeychain()

        #if DEBUG
        if args.contains("-signedIn") {
            account = Account(userID: "ui-test", name: "Sam Parent", email: "sam@example.com")
            isFakeAccount = true
        }
        #endif

        // The user stopped using Sign in with Apple for this app (Settings → Apple Account).
        revokeObserver = NotificationCenter.default.addObserver(
            forName: ASAuthorizationAppleIDProvider.credentialRevokedNotification, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.signOut() }
        }
    }

    deinit {
        if let revokeObserver { NotificationCenter.default.removeObserver(revokeObserver) }
    }

    /// Result of `SignInWithAppleButton`.
    func handle(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else { return }
            let previous = account?.userID == credential.user ? account : loadFromKeychain().flatMap { $0.userID == credential.user ? $0 : nil }
            let name = credential.fullName.flatMap { PersonNameComponentsFormatter().string(from: $0) }.flatMap { $0.isEmpty ? nil : $0 }
            let signedIn = Account(userID: credential.user,
                                   name: name ?? previous?.name,
                                   email: credential.email ?? previous?.email)
            saveToKeychain(signedIn)
            account = signedIn
            isFakeAccount = false
            errorMessage = nil

        case .failure(let error):
            if (error as? ASAuthorizationError)?.code == .canceled { return }
            errorMessage = "Sign in with Apple isn't available right now. Please try again later."
            #if DEBUG
            print("AccountManager: sign-in failed \(error)")
            #endif
        }
    }

    /// Call on launch: signs out if the Apple ID no longer authorizes this app.
    func refreshCredentialState() async {
        guard let userID = account?.userID, !isFakeAccount else { return }
        do {
            let state = try await ASAuthorizationAppleIDProvider().credentialState(forUserID: userID)
            if state == .revoked || state == .notFound { signOut() }
        } catch {
            // Offline or unavailable: keep the account until we can check.
        }
    }

    func signOut() {
        deleteFromKeychain()
        account = nil
        isFakeAccount = false
    }

    /// Hub "Delete Account": removes the account from this device. Progress is reset by the caller.
    /// (Revoking the Apple token needs a server call to Apple's /auth/revoke; with no server,
    /// the hub tells grown-ups how to stop using Sign in with Apple in Settings.)
    func deleteAccount() {
        signOut()
    }

    // MARK: Keychain

    private var baseQuery: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: service,
         kSecAttrAccount as String: keychainAccount]
    }

    private func loadFromKeychain() -> Account? {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return try? JSONDecoder().decode(Account.self, from: data)
    }

    private func saveToKeychain(_ account: Account) {
        guard let data = try? JSONEncoder().encode(account) else { return }
        deleteFromKeychain()
        var query = baseQuery
        query[kSecValueData as String] = data
        query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        SecItemAdd(query as CFDictionary, nil)
    }

    private func deleteFromKeychain() {
        SecItemDelete(baseQuery as CFDictionary)
    }
}

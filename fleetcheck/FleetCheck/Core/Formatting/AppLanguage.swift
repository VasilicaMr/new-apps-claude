import Foundation

/// The language DriveCap shows, chosen in Settings. It writes the same `AppleLanguages` override that iOS
/// Settings writes for an app's own language, so both stay in sync. Bundles read it at launch, so the new
/// language shows the next time DriveCap opens.
enum AppLanguage {
    static let supported = ["en", "ro", "fr"]

    private static let key = "AppleLanguages"
    /// `AppleLanguages` also reads through to the iPhone's own list, so the choice is kept separately too.
    private static let chosenKey = "appLanguage"

    /// The language picked in DriveCap, or nil when it follows the iPhone (or was changed in iOS Settings since).
    static var chosen: String? {
        guard let code = UserDefaults.standard.string(forKey: chosenKey),
              Bundle.main.preferredLocalizations.first == code else { return nil }
        return code
    }

    /// Pass "" to follow the iPhone's language again.
    static func choose(_ code: String) {
        if code.isEmpty {
            UserDefaults.standard.removeObject(forKey: key)
            UserDefaults.standard.removeObject(forKey: chosenKey)
        } else {
            UserDefaults.standard.set([code], forKey: key)
            UserDefaults.standard.set(code, forKey: chosenKey)
        }
    }

    /// A language named in itself ("Română", "Français"), the way people look for it.
    static func name(_ code: String) -> String {
        let locale = Locale(identifier: code)
        return locale.localizedString(forLanguageCode: code)?.capitalized(with: locale) ?? code
    }
}

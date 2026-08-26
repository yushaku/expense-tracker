import Foundation

enum VoiceShortcutConfiguration {
    static var bundledInstallationURL: URL? {
        installationURL(
            shortcutID: Bundle.main.object(forInfoDictionaryKey: "MonMonVoiceShortcutID") as? String
        )
    }

    static func installationURL(shortcutID: String?) -> URL? {
        guard let shortcutID else {
            return nil
        }

        let trimmedID = shortcutID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard
            !trimmedID.isEmpty,
            trimmedID.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" })
        else {
            return nil
        }

        return URL(string: "https://www.icloud.com/shortcuts/\(trimmedID)")
    }
}

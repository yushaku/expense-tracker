import Foundation
import SwiftUI

/// Which language the owner wants the app written in. `system` follows the
/// device, which is what a phone set to Vietnamese already asks for.
///
/// The app carries its own switch rather than leaving this to iOS because the
/// two languages here belong to one household: the interface may be wanted in
/// English while the phone stays Vietnamese, or the other way round.
enum AppLanguage: String, CaseIterable, Identifiable {
    case system
    case english
    case vietnamese

    static let storageKey = "appLanguage"

    var id: String { rawValue }

    /// Each language names itself, so the choice is legible to someone who
    /// cannot read the language currently on show. These are never translated.
    var displayName: String {
        switch self {
        case .system:
            "System"
        case .english:
            "English"
        case .vietnamese:
            "Tiếng Việt"
        }
    }

    var symbolName: String {
        switch self {
        case .system:
            "iphone"
        case .english:
            "textformat"
        case .vietnamese:
            "textformat"
        }
    }

    /// `nil` hands the choice back to the device.
    var localeIdentifier: String? {
        switch self {
        case .system:
            nil
        case .english:
            "en"
        case .vietnamese:
            "vi"
        }
    }

    /// The locale every localized string and date format is resolved against.
    /// Following the device means following it as it changes, so the system
    /// choice autoupdates rather than freezing whatever was set at launch.
    var locale: Locale {
        guard let localeIdentifier else {
            return .autoupdatingCurrent
        }

        return Locale(identifier: localeIdentifier)
    }

    /// Where a key is looked up. Foundation resolves a key against the bundle's
    /// own language and ignores the locale handed to `String(localized:)` —
    /// that one only formats what is interpolated. So code outside the view
    /// tree, which cannot lean on SwiftUI's own resolution, asks the language's
    /// own catalogue directly. English is the language the keys are written in
    /// and has no catalogue of its own, which is why the main bundle answers.
    static func bundle(for locale: Locale) -> Bundle {
        guard let code = locale.language.languageCode?.identifier,
            let path = Bundle.main.path(forResource: code, ofType: "lproj"),
            let bundle = Bundle(path: path)
        else {
            return .main
        }

        return bundle
    }

    /// The current choice, read straight from storage. Code outside the view
    /// tree — a seeder, a formatter helper — has no environment to read, and a
    /// sheet may not inherit one, so both come through here.
    static var stored: AppLanguage {
        guard let rawValue = UserDefaults.standard.string(forKey: storageKey) else {
            return .system
        }

        return AppLanguage(rawValue: rawValue) ?? .system
    }
}

/// Localized text for code that has no view to read a locale from — a seeder, a
/// phrase composed for a sentence, a label handed to VoiceOver as a `String`.
///
/// Views should keep passing plain literals to `Text` and friends, which SwiftUI
/// resolves against the environment on its own. This is the way in for
/// everything else.
enum AppText {
    static func string(_ key: String.LocalizationValue, in locale: Locale) -> String {
        String(localized: key, bundle: AppLanguage.bundle(for: locale), locale: locale)
    }
}

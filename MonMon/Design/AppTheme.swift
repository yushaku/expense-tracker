import Foundation
import SwiftUI

/// Which appearance the owner picked. `system` follows the device.
enum AppTheme: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    static let storageKey = "appTheme"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .system:
            "System"
        case .light:
            "Light"
        case .dark:
            "Dark"
        }
    }

    var symbolName: String {
        switch self {
        case .system:
            "circle.lefthalf.filled"
        case .light:
            "sun.max.fill"
        case .dark:
            "moon.fill"
        }
    }

    /// `nil` hands the choice back to the system.
    var colorScheme: ColorScheme? {
        switch self {
        case .system:
            nil
        case .light:
            .light
        case .dark:
            .dark
        }
    }

    /// The current choice, read straight from storage. `MonMonTheme.colorScheme`
    /// goes through here so a sheet — which inherits no colour scheme from the
    /// screen that presented it — still shows the theme the owner picked.
    static var stored: AppTheme {
        guard let rawValue = UserDefaults.standard.string(forKey: storageKey) else {
            return .system
        }

        return AppTheme(rawValue: rawValue) ?? .system
    }
}

import SwiftUI

enum CashAccountKind: String, Codable, CaseIterable {
    case cash
    case bank
    case credit

    var displayNameKey: String {
        switch self {
        case .cash:
            "Cash"
        case .bank:
            "Bank"
        case .credit:
            "Credit"
        }
    }

    var displayName: LocalizedStringKey {
        LocalizedStringKey(displayNameKey)
    }

    func displayName(in locale: Locale) -> String {
        AppText.string(key: displayNameKey, in: locale)
    }

    /// Credit cards carry what you owe, so their balance is allowed to go below
    /// zero. Cash and bank accounts cannot.
    var allowsNegativeBalance: Bool {
        self == .credit
    }
}

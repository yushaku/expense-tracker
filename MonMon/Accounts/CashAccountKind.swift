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

extension CashAccountKind {
    /// How an account of this kind is drawn wherever one is listed: the card on
    /// the Accounts screen, and the filters a report is cut down by. Kept beside
    /// the kind rather than in one of those screens, so the two can never draw
    /// the same account differently.
    var iconName: String {
        switch self {
        case .cash:
            "banknote.fill"
        case .bank:
            "building.columns.fill"
        case .credit:
            "creditcard.fill"
        }
    }

    var tint: Color {
        switch self {
        case .cash:
            MonMonTheme.accent
        case .bank:
            MonMonTheme.bank
        case .credit:
            MonMonTheme.credit
        }
    }
}

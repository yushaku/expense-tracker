import SwiftUI

enum TransactionKind: String, Codable, CaseIterable {
    case income
    case expense

    /// The key the catalogue answers, kept once and handed out two ways: as a
    /// key a view resolves against the language on show, and resolved here for a
    /// sentence or a spoken label, which need a `String`.
    var nameKey: String {
        switch self {
        case .income:
            "Income"
        case .expense:
            "Expense"
        }
    }

    var displayName: LocalizedStringKey {
        LocalizedStringKey(nameKey)
    }

    func displayName(in locale: Locale) -> String {
        AppText.string(key: nameKey, in: locale)
    }

    /// Amounts are always stored positive; direction lives here so no call site
    /// has to agree on a sign convention.
    var signLabel: String {
        switch self {
        case .income:
            "+"
        case .expense:
            "−"
        }
    }

    var symbolName: String {
        switch self {
        case .income:
            "arrow.down.left"
        case .expense:
            "arrow.up.right"
        }
    }
}

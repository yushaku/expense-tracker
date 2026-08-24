import Foundation
import SwiftUI

/// Which way a debt points. Like `TransactionKind`, it exists so every amount
/// can be stored positive and no call site has to agree on a sign convention.
enum DebtDirection: String, Codable, CaseIterable {
    /// Money the owner took from someone else and owes back. A liability.
    case borrowed
    /// Money the owner handed to someone else and expects back. An asset.
    case lent

    var displayNameKey: String {
        switch self {
        case .borrowed:
            "Borrowed"
        case .lent:
            "Lent out"
        }
    }

    var displayName: LocalizedStringKey {
        LocalizedStringKey(displayNameKey)
    }

    func displayName(in locale: Locale) -> String {
        AppText.string(key: displayNameKey, in: locale)
    }

    /// The preposition the counterparty needs, so one stored name reads right in
    /// both directions: "Borrowed from Anh Minh", "Lent to Anh Minh". A language
    /// that words this differently answers with its own word here.
    func counterpartyPreposition(in locale: Locale) -> String {
        switch self {
        case .borrowed:
            AppText.string("from", in: locale)
        case .lent:
            AppText.string("to", in: locale)
        }
    }

    /// What opening the debt does to the account it names: borrowing puts money
    /// in, lending takes it out. A payment moves the opposite way.
    var openingSign: Decimal {
        switch self {
        case .borrowed:
            1
        case .lent:
            -1
        }
    }

    /// The sign the opening shows on screen, matching `TransactionKind`.
    var signLabel: String {
        switch self {
        case .borrowed:
            "+"
        case .lent:
            "−"
        }
    }

    var symbolName: String {
        switch self {
        case .borrowed:
            "arrow.down.left.circle.fill"
        case .lent:
            "arrow.up.right.circle.fill"
        }
    }
}

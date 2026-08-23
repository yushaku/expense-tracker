import Foundation

/// Which way a debt points. Like `TransactionKind`, it exists so every amount
/// can be stored positive and no call site has to agree on a sign convention.
enum DebtDirection: String, Codable, CaseIterable {
    /// Money the owner took from someone else and owes back. A liability.
    case borrowed
    /// Money the owner handed to someone else and expects back. An asset.
    case lent

    var displayName: String {
        switch self {
        case .borrowed:
            "Borrowed"
        case .lent:
            "Lent out"
        }
    }

    /// The preposition the counterparty needs, so one stored name reads right in
    /// both directions: "Borrowed from Anh Minh", "Lent to Anh Minh".
    var counterpartyPreposition: String {
        switch self {
        case .borrowed:
            "from"
        case .lent:
            "to"
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

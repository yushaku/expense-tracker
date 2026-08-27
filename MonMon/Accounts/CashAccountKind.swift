import SwiftUI

enum CashAccountKind: Codable, CaseIterable, RawRepresentable {
    case normal
    case credit

    typealias RawValue = String

    init?(rawValue: String) {
        switch rawValue {
        case "normal", "cash", "bank":
            self = .normal
        case "credit":
            self = .credit
        default:
            return nil
        }
    }

    var rawValue: String {
        switch self {
        case .normal:
            "normal"
        case .credit:
            "credit"
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        guard let value = Self(rawValue: rawValue) else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unknown account kind: \(rawValue)"
            )
        }
        self = value
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }

    // Temporary source adapters keep intermediate migration commits compiling.
    // They are removed after every production and test consumer uses `.normal`.
    static let cash = Self.normal
    static let bank = Self.normal

    var displayNameKey: String {
        switch self {
        case .normal:
            "Normal"
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
        case .normal:
            "wallet.bifold.fill"
        case .credit:
            "creditcard.fill"
        }
    }

    var tint: Color {
        switch self {
        case .normal:
            MonMonTheme.accent
        case .credit:
            MonMonTheme.credit
        }
    }
}

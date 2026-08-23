enum CashAccountKind: String, Codable, CaseIterable {
    case cash
    case bank
    case credit

    var displayName: String {
        switch self {
        case .cash:
            "Cash"
        case .bank:
            "Bank"
        case .credit:
            "Credit"
        }
    }

    /// Credit cards carry what you owe, so their balance is allowed to go below
    /// zero. Cash and bank accounts cannot.
    var allowsNegativeBalance: Bool {
        self == .credit
    }
}

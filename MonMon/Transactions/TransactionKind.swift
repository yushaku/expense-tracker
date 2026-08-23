enum TransactionKind: String, Codable, CaseIterable {
    case income
    case expense

    var displayName: String {
        switch self {
        case .income:
            "Income"
        case .expense:
            "Expense"
        }
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

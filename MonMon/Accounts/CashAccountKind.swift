enum CashAccountKind: String, Codable, CaseIterable {
    case cash
    case bank

    var displayName: String {
        switch self {
        case .cash:
            "Cash"
        case .bank:
            "Bank"
        }
    }
}

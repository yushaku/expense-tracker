import Foundation

struct StatementAccountMapping {
    static let storageKey = "statementAccountMappings.v1"

    private let defaults: UserDefaults

    init(defaults: UserDefaults) {
        self.defaults = defaults
    }

    func resolve(
        bank: BankStatementBank,
        accountLastFour: String?,
        accounts: [StatementImportAccountSnapshot]
    ) -> UUID? {
        guard let key = mappingKey(bank: bank, accountLastFour: accountLastFour),
            let rawAccountID = mappings[key],
            let accountID = UUID(uuidString: rawAccountID)
        else {
            return nil
        }

        return accounts.first {
            $0.id == accountID && $0.currencyCode == VNDCurrency.code
        }?.id
    }

    /// The commit service calls this only after its financial save completes.
    /// Keeping the success signal in the boundary also makes an accidental
    /// pre-save call a no-op rather than changing the owner's default early.
    @discardableResult
    func remember(
        accountID: UUID,
        bank: BankStatementBank,
        accountLastFour: String?,
        accounts: [StatementImportAccountSnapshot],
        financialCommitSucceeded: Bool
    ) -> Bool {
        guard financialCommitSucceeded,
            let key = mappingKey(bank: bank, accountLastFour: accountLastFour),
            accounts.contains(where: {
                $0.id == accountID && $0.currencyCode == VNDCurrency.code
            })
        else {
            return false
        }

        var updatedMappings = mappings
        updatedMappings[key] = accountID.uuidString
        defaults.set(updatedMappings, forKey: Self.storageKey)
        return true
    }

    private var mappings: [String: String] {
        defaults.dictionary(forKey: Self.storageKey) as? [String: String] ?? [:]
    }

    private func mappingKey(
        bank: BankStatementBank,
        accountLastFour: String?
    ) -> String? {
        guard let accountLastFour,
            accountLastFour.utf8.count == 4,
            accountLastFour.utf8.allSatisfy({ (48...57).contains($0) })
        else {
            return nil
        }

        return "\(bank.rawValue)|\(accountLastFour)"
    }
}

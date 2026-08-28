import Foundation
import Testing

@testable import MonMon

@Suite("Account report summary")
struct AccountReportSummaryTests {
    private let createdAt = Date(timeIntervalSince1970: 1_700_000_000)

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        TransactionPeriod.calendar.date(
            from: DateComponents(year: year, month: month, day: day)
        ) ?? .distantPast
    }

    private func makeAccount(_ name: String) -> CashAccount {
        CashAccount(
            id: UUID(),
            name: name,
            kind: .normal,
            openingBalance: 0,
            currencyCode: VNDCurrency.code,
            createdAt: createdAt
        )
    }

    private func makeTransaction(
        id: UUID = UUID(),
        kind: TransactionKind = .expense,
        amount: Decimal,
        account: CashAccount,
        occurredAt: Date? = nil
    ) -> MoneyTransaction {
        MoneyTransaction(
            id: id,
            kind: kind,
            amount: amount,
            occurredAt: occurredAt ?? createdAt,
            note: "",
            accountID: account.id,
            categoryID: nil,
            sourceRuleID: nil,
            currencyCode: VNDCurrency.code,
            createdAt: createdAt
        )
    }

    private func makeTransfer(
        id: UUID = UUID(),
        amount: Decimal = 100_000,
        from source: CashAccount,
        to destination: CashAccount,
        occurredAt: Date
    ) -> AccountTransfer {
        AccountTransfer(
            id: id,
            amount: amount,
            occurredAt: occurredAt,
            note: "",
            sourceAccountID: source.id,
            destinationAccountID: destination.id,
            currencyCode: VNDCurrency.code,
            createdAt: createdAt
        )
    }

    @Test("Account spending counts expenses only and sorts the largest first")
    func spendingRowsUseExpensesOnly() {
        let wallet = makeAccount("Wallet")
        let bank = makeAccount("Bank")
        let unused = makeAccount("Unused")
        let rows = AccountSpendingSummary.rows(
            accounts: [wallet, bank, unused],
            transactions: [
                makeTransaction(amount: 100_000, account: wallet),
                makeTransaction(amount: 50_000, account: wallet),
                makeTransaction(kind: .income, amount: 9_000_000, account: wallet),
                makeTransaction(amount: 400_000, account: bank),
            ]
        )

        #expect(
            rows
                == [
                    AccountSpendingRow(
                        accountID: bank.id,
                        amount: 400_000,
                        count: 1
                    ),
                    AccountSpendingRow(
                        accountID: wallet.id,
                        amount: 150_000,
                        count: 2
                    ),
                ]
        )
    }

    @Test("Equal account spending keeps the account order")
    func equalSpendingKeepsAccountOrder() {
        let first = makeAccount("First")
        let second = makeAccount("Second")
        let rows = AccountSpendingSummary.rows(
            accounts: [first, second],
            transactions: [
                makeTransaction(amount: 100_000, account: second),
                makeTransaction(amount: 100_000, account: first),
            ]
        )

        #expect(rows.map(\.accountID) == [first.id, second.id])
    }

    @Test("Account activity includes its transactions and both transfer directions")
    func activityIncludesEveryAccountMovement() {
        let wallet = makeAccount("Wallet")
        let bank = makeAccount("Bank")
        let other = makeAccount("Other")
        let olderTransactionID = UUID()
        let incomingTransferID = UUID()
        let outgoingTransferID = UUID()
        let newestTransactionID = UUID()

        let activity = AccountActivityItem.items(
            for: wallet.id,
            transactions: [
                makeTransaction(
                    id: olderTransactionID,
                    amount: 100_000,
                    account: wallet,
                    occurredAt: date(2026, 1, 1)
                ),
                makeTransaction(
                    id: newestTransactionID,
                    kind: .income,
                    amount: 300_000,
                    account: wallet,
                    occurredAt: date(2026, 1, 4)
                ),
                makeTransaction(
                    amount: 900_000,
                    account: other,
                    occurredAt: date(2026, 1, 5)
                ),
            ],
            transfers: [
                makeTransfer(
                    id: incomingTransferID,
                    from: bank,
                    to: wallet,
                    occurredAt: date(2026, 1, 2)
                ),
                makeTransfer(
                    id: outgoingTransferID,
                    from: wallet,
                    to: bank,
                    occurredAt: date(2026, 1, 3)
                ),
                makeTransfer(
                    from: bank,
                    to: other,
                    occurredAt: date(2026, 1, 6)
                ),
            ]
        )

        #expect(
            activity.map(\.id)
                == [
                    .transaction(newestTransactionID),
                    .transfer(outgoingTransferID),
                    .transfer(incomingTransferID),
                    .transaction(olderTransactionID),
                ]
        )
    }

    @Test("Equal activity timestamps use a stable kind and identifier order")
    func equalDatesHaveStableOrder() {
        let wallet = makeAccount("Wallet")
        let bank = makeAccount("Bank")
        let timestamp = date(2026, 1, 1)
        let earlierID = UUID(uuidString: "00000000-0000-0000-0000-000000000001") ?? UUID()
        let laterID = UUID(uuidString: "00000000-0000-0000-0000-000000000002") ?? UUID()
        let transferID = UUID(uuidString: "00000000-0000-0000-0000-000000000003") ?? UUID()

        let activity = AccountActivityItem.items(
            for: wallet.id,
            transactions: [
                makeTransaction(
                    id: laterID,
                    amount: 200_000,
                    account: wallet,
                    occurredAt: timestamp
                ),
                makeTransaction(
                    id: earlierID,
                    amount: 100_000,
                    account: wallet,
                    occurredAt: timestamp
                ),
            ],
            transfers: [
                makeTransfer(
                    id: transferID,
                    from: wallet,
                    to: bank,
                    occurredAt: timestamp
                )
            ]
        )

        #expect(
            activity.map(\.id)
                == [
                    .transaction(earlierID),
                    .transaction(laterID),
                    .transfer(transferID),
                ]
        )
    }

    @Test("Linked sources count every account reference by source kind")
    func linkedSourcesCountAccountReferences() {
        let wallet = makeAccount("Wallet")
        let deposit = SavingsDeposit(
            id: UUID(),
            name: "Term deposit",
            principal: 10_000_000,
            annualInterestRate: 5,
            termMonths: 6,
            openedAt: createdAt,
            currencyCode: VNDCurrency.code,
            createdAt: createdAt,
            sourceAccountID: wallet.id
        )
        let withdrawal = SavingsWithdrawal(
            id: UUID(),
            depositID: deposit.id,
            principal: 1_000_000,
            amountReceived: 1_050_000,
            destinationAccountID: wallet.id,
            withdrawnAt: createdAt,
            currencyCode: VNDCurrency.code,
            createdAt: createdAt
        )
        let holding = FundHolding(
            id: UUID(),
            instrumentID: UUID(),
            units: 10,
            averageCostPerUnit: 100_000,
            createdAt: createdAt,
            sourceAccountID: wallet.id
        )
        let sale = FundSale(
            id: UUID(),
            holdingID: holding.id,
            units: 2,
            pricePerUnit: 120_000,
            proceedsAccountID: wallet.id,
            soldAt: createdAt,
            currencyCode: VNDCurrency.code,
            createdAt: createdAt
        )
        let debt = Debt(
            id: UUID(),
            counterparty: "Friend",
            direction: .borrowed,
            principal: 3_000_000,
            annualInterestRate: 0,
            openedAt: createdAt,
            dueDate: nil,
            accountID: wallet.id,
            note: "",
            currencyCode: VNDCurrency.code,
            createdAt: createdAt
        )
        let payment = DebtPayment(
            id: UUID(),
            debtID: debt.id,
            amount: 500_000,
            occurredAt: createdAt,
            accountID: wallet.id,
            note: "",
            currencyCode: VNDCurrency.code,
            createdAt: createdAt
        )
        let recurring = RecurringRule(
            id: UUID(),
            kind: .expense,
            amount: 200_000,
            note: "Internet",
            accountID: wallet.id,
            categoryID: nil,
            currencyCode: VNDCurrency.code,
            frequency: .monthly,
            interval: 1,
            anchorDate: createdAt,
            endDate: nil,
            isPaused: false,
            lastGeneratedAt: nil,
            createdAt: createdAt
        )

        let rows = AccountLinkedSourceSummary.rows(
            for: wallet,
            deposits: [deposit],
            withdrawals: [withdrawal],
            holdings: [holding],
            sales: [sale],
            debts: [debt],
            payments: [payment],
            recurringRules: [recurring]
        )

        #expect(
            rows
                == [
                    AccountLinkedSourceRow(kind: .savings, count: 2),
                    AccountLinkedSourceRow(kind: .funds, count: 2),
                    AccountLinkedSourceRow(kind: .debts, count: 2),
                    AccountLinkedSourceRow(kind: .recurring, count: 1),
                ]
        )
    }

    @Test("Accounts with no linked sources return no source rows")
    func noLinkedSourcesReturnsNoRows() {
        let account = makeAccount("Wallet")

        #expect(
            AccountLinkedSourceSummary.rows(
                for: account,
                deposits: [],
                withdrawals: [],
                holdings: [],
                sales: [],
                debts: [],
                payments: [],
                recurringRules: []
            ).isEmpty
        )
    }
}

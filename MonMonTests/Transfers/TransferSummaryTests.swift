import Foundation
import Testing

@testable import MonMon

@Suite("Transfer summary")
struct TransferSummaryTests {
    private let createdAt = Date(timeIntervalSince1970: 1_700_000_000)

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        let components = DateComponents(year: year, month: month, day: day)
        return TransactionPeriod.calendar.date(from: components) ?? .distantPast
    }

    private func makeAccount(
        name: String = "Wallet",
        kind: CashAccountKind = .cash,
        openingBalance: Decimal = 0
    ) -> CashAccount {
        CashAccount(
            id: UUID(),
            name: name,
            kind: kind,
            openingBalance: openingBalance,
            currencyCode: VNDCurrency.code,
            createdAt: createdAt
        )
    }

    private func makeTransfer(
        amount: Decimal,
        from source: CashAccount,
        to destination: CashAccount,
        occurredAt: Date? = nil
    ) -> AccountTransfer {
        AccountTransfer(
            id: UUID(),
            amount: amount,
            occurredAt: occurredAt ?? createdAt,
            note: "",
            sourceAccountID: source.id,
            destinationAccountID: destination.id,
            currencyCode: VNDCurrency.code,
            createdAt: createdAt
        )
    }

    @Test("No transfers total to zero")
    func emptyTotalsAreZero() {
        #expect(TransferSummary.total(of: []) == 0)
    }

    @Test("A transfer lowers one account and raises the other")
    func netFlowSplitsBothWays() {
        let wallet = makeAccount(name: "Wallet")
        let bank = makeAccount(name: "Bank", kind: .bank)
        let transfers = [makeTransfer(amount: 2_000_000, from: bank, to: wallet)]

        #expect(TransferSummary.netFlow(for: bank, transfers: transfers) == -2_000_000)
        #expect(TransferSummary.netFlow(for: wallet, transfers: transfers) == 2_000_000)
    }

    @Test("An account untouched by a transfer does not move")
    func untouchedAccountsStayPut() {
        let wallet = makeAccount(name: "Wallet")
        let bank = makeAccount(name: "Bank", kind: .bank)
        let other = makeAccount(name: "Other", kind: .bank)
        let transfers = [makeTransfer(amount: 2_000_000, from: bank, to: wallet)]

        #expect(TransferSummary.netFlow(for: other, transfers: transfers) == 0)
    }

    @Test("Transfers in both directions net out")
    func oppositeTransfersCancel() {
        let wallet = makeAccount(name: "Wallet")
        let bank = makeAccount(name: "Bank", kind: .bank)
        let transfers = [
            makeTransfer(amount: 2_000_000, from: bank, to: wallet),
            makeTransfer(amount: 500_000, from: wallet, to: bank),
        ]

        #expect(TransferSummary.netFlow(for: wallet, transfers: transfers) == 1_500_000)
        #expect(TransferSummary.netFlow(for: bank, transfers: transfers) == -1_500_000)
        #expect(TransferSummary.total(of: transfers) == 2_500_000)
    }

    @Test("Both ends of a transfer count towards the account that owns them")
    func countCoversBothEnds() {
        let wallet = makeAccount(name: "Wallet")
        let bank = makeAccount(name: "Bank", kind: .bank)
        let other = makeAccount(name: "Other", kind: .bank)
        let transfers = [
            makeTransfer(amount: 2_000_000, from: bank, to: wallet),
            makeTransfer(amount: 500_000, from: wallet, to: bank),
        ]

        #expect(TransferSummary.count(for: wallet, transfers: transfers) == 2)
        #expect(TransferSummary.count(for: bank, transfers: transfers) == 2)
        #expect(TransferSummary.count(for: other, transfers: transfers) == 0)
    }

    @Test("Only the transfers inside the range are kept")
    func rangeFiltersByDate() {
        let wallet = makeAccount(name: "Wallet")
        let bank = makeAccount(name: "Bank", kind: .bank)
        let transfers = [
            makeTransfer(
                amount: 1_000_000,
                from: bank,
                to: wallet,
                occurredAt: date(2025, 3, 10)
            ),
            makeTransfer(
                amount: 2_000_000,
                from: bank,
                to: wallet,
                occurredAt: date(2025, 4, 2)
            ),
        ]

        let march = TransferSummary.inRange(
            .month(containing: date(2025, 3, 15)),
            transfers: transfers
        )

        #expect(march.count == 1)
        #expect(TransferSummary.total(of: march) == 1_000_000)
    }

    @Test("A transfer moves a balance without changing the total")
    func balancesMoveButTheTotalHolds() {
        let wallet = makeAccount(name: "Wallet", openingBalance: 1_000_000)
        let bank = makeAccount(name: "Bank", kind: .bank, openingBalance: 10_000_000)
        let accounts = [wallet, bank]
        let transfers = [makeTransfer(amount: 2_000_000, from: bank, to: wallet)]

        #expect(
            CashBalanceSummary.available(
                for: wallet,
                deposits: [],
                holdings: [],
                withdrawals: [],
                transactions: [],
                transfers: transfers,
                debts: [],
                payments: [],
                sales: []
            ) == 3_000_000
        )
        #expect(
            CashBalanceSummary.available(
                for: bank,
                deposits: [],
                holdings: [],
                withdrawals: [],
                transactions: [],
                transfers: transfers,
                debts: [],
                payments: [],
                sales: []
            ) == 8_000_000
        )
        #expect(
            CashBalanceSummary.totalAvailable(
                of: accounts,
                deposits: [],
                holdings: [],
                withdrawals: [],
                transactions: [],
                transfers: transfers,
                debts: [],
                payments: [],
                sales: []
            ) == 11_000_000
        )
    }

    @Test("A transfer leaves net worth exactly where it was")
    func netWorthIgnoresTransfers() {
        let wallet = makeAccount(name: "Wallet", openingBalance: 1_000_000)
        let bank = makeAccount(name: "Bank", kind: .bank, openingBalance: 10_000_000)
        let accounts = [wallet, bank]
        let transfers = [makeTransfer(amount: 2_000_000, from: bank, to: wallet)]

        let before = AssetSummary.netWorth(
            accounts: accounts,
            deposits: [],
            withdrawals: [],
            holdings: [],
            instruments: [],
            transactions: [],
            transfers: [],
            debts: [],
            payments: [],
            sales: []
        )
        let after = AssetSummary.netWorth(
            accounts: accounts,
            deposits: [],
            withdrawals: [],
            holdings: [],
            instruments: [],
            transactions: [],
            transfers: transfers,
            debts: [],
            payments: [],
            sales: []
        )

        #expect(before == 11_000_000)
        #expect(after == before)
    }

    @Test("An account can be transferred into the red only where that is allowed")
    func transfersCanOverdrawACreditCard() {
        let card = makeAccount(name: "Visa", kind: .credit, openingBalance: 0)
        let bank = makeAccount(name: "Bank", kind: .bank, openingBalance: 10_000_000)
        let transfers = [makeTransfer(amount: 3_000_000, from: card, to: bank)]

        #expect(
            CashBalanceSummary.available(
                for: card,
                deposits: [],
                holdings: [],
                withdrawals: [],
                transactions: [],
                transfers: transfers,
                debts: [],
                payments: [],
                sales: []
            ) == -3_000_000
        )
        #expect(
            AssetAllocation.overdraft(
                accounts: [card, bank],
                deposits: [],
                withdrawals: [],
                holdings: [],
                transactions: [],
                transfers: transfers,
                debts: [],
                payments: [],
                sales: []
            ) == 3_000_000
        )
    }
}

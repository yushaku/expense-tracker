import Foundation
import SwiftData
import Testing

@testable import MonMon

@Suite("Savings withdrawals and net worth")
struct SavingsWithdrawalIntegrationTests {
    private let openedAt = Date(timeIntervalSince1970: 1_700_000_000)

    private func makeAccount(openingBalance: Decimal = 100_000_000) -> CashAccount {
        CashAccount(
            id: UUID(),
            name: "Bank",
            kind: .bank,
            openingBalance: openingBalance,
            currencyCode: VNDCurrency.code,
            createdAt: openedAt
        )
    }

    private func makeDeposit(accountID: UUID) -> SavingsDeposit {
        SavingsDeposit(
            id: UUID(),
            name: "Deposit",
            principal: 100_000_000,
            annualInterestRate: 6,
            termMonths: 12,
            openedAt: openedAt,
            currencyCode: VNDCurrency.code,
            createdAt: openedAt,
            sourceAccountID: accountID
        )
    }

    private func makeWithdrawal(
        deposit: SavingsDeposit,
        accountID: UUID,
        principal: Decimal,
        received: Decimal,
        withdrawnAt: Date? = nil
    ) -> SavingsWithdrawal {
        SavingsWithdrawal(
            id: UUID(),
            depositID: deposit.id,
            principal: principal,
            amountReceived: received,
            destinationAccountID: accountID,
            withdrawnAt: withdrawnAt ?? openedAt.addingTimeInterval(86_400),
            createdAt: withdrawnAt ?? openedAt.addingTimeInterval(86_400)
        )
    }

    private func netWorth(
        account: CashAccount,
        deposit: SavingsDeposit,
        withdrawals: [SavingsWithdrawal]
    ) -> Decimal {
        AssetSummary.netWorth(
            accounts: [account],
            deposits: [deposit],
            withdrawals: withdrawals,
            holdings: [],
            instruments: [],
            transactions: [],
            transfers: [],
            debts: [],
            payments: [],
            sales: []
        )
    }

    @Test("Withdrawing principal at par moves value from savings to cash exactly once")
    func principalAtParDoesNotMoveNetWorth() {
        let account = makeAccount()
        let deposit = makeDeposit(accountID: account.id)
        let withdrawal = makeWithdrawal(
            deposit: deposit,
            accountID: account.id,
            principal: 30_000_000,
            received: 30_000_000
        )

        #expect(netWorth(account: account, deposit: deposit, withdrawals: []) == 100_000_000)
        #expect(
            netWorth(account: account, deposit: deposit, withdrawals: [withdrawal])
                == 100_000_000
        )
    }

    @Test("Realized interest changes net worth exactly once")
    func realizedInterestAppearsOnce() {
        let account = makeAccount()
        let deposit = makeDeposit(accountID: account.id)
        let withdrawal = makeWithdrawal(
            deposit: deposit,
            accountID: account.id,
            principal: 100_000_000,
            received: 100_500_000
        )

        #expect(
            netWorth(account: account, deposit: deposit, withdrawals: [withdrawal])
                == 100_500_000
        )
        #expect(
            InvestmentSummary.total(
                deposits: [deposit],
                withdrawals: [withdrawal],
                holdings: [],
                instruments: [],
                sales: []
            ) == 0
        )
    }

    @Test("An early-withdrawal loss lowers net worth by only the loss")
    func earlyLossAppearsOnce() {
        let account = makeAccount()
        let deposit = makeDeposit(accountID: account.id)
        let withdrawal = makeWithdrawal(
            deposit: deposit,
            accountID: account.id,
            principal: 100_000_000,
            received: 99_000_000
        )

        #expect(
            netWorth(account: account, deposit: deposit, withdrawals: [withdrawal])
                == 99_000_000
        )
    }

    @Test("History before a withdrawal still holds the full principal")
    func historyPreservesEarlierPrincipal() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        let account = makeAccount()
        let deposit = makeDeposit(accountID: account.id)
        let withdrawnAt = try #require(
            calendar.date(byAdding: .month, value: 2, to: openedAt)
        )
        let asOf = try #require(calendar.date(byAdding: .month, value: 3, to: openedAt))
        let withdrawal = makeWithdrawal(
            deposit: deposit,
            accountID: account.id,
            principal: 40_000_000,
            received: 40_000_000,
            withdrawnAt: withdrawnAt
        )

        let points = AssetHistory.points(
            accounts: [account],
            deposits: [deposit],
            withdrawals: [withdrawal],
            holdings: [],
            instruments: [],
            transactions: [],
            transfers: [],
            debts: [],
            payments: [],
            sales: [],
            asOf: asOf,
            calendar: calendar
        )

        let before = try #require(points.last { $0.date < withdrawnAt })
        #expect(before.composition.first { $0.kind == .savings }?.amount == 100_000_000)
        #expect(points.last?.composition.first { $0.kind == .savings }?.amount == 60_000_000)
    }
}

@Suite("Savings withdrawal persistence")
@MainActor
struct SavingsWithdrawalPersistenceTests {
    @Test("A withdrawal round-trips every stored field")
    func withdrawalRoundTrips() throws {
        let container = try ModelContainer(
            for: Schema(MonMonSchema.models),
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = container.mainContext
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let depositID = UUID()
        let accountID = UUID()
        let withdrawal = SavingsWithdrawal(
            id: UUID(),
            depositID: depositID,
            principal: 30_000_000,
            amountReceived: 30_100_000,
            destinationAccountID: accountID,
            withdrawnAt: date,
            note: "partial",
            createdAt: date
        )

        context.insert(withdrawal)
        try context.save()

        let saved = try #require(
            try context.fetch(FetchDescriptor<SavingsWithdrawal>()).first
        )
        #expect(saved.depositID == depositID)
        #expect(saved.principal == 30_000_000)
        #expect(saved.amountReceived == 30_100_000)
        #expect(saved.destinationAccountID == accountID)
        #expect(saved.withdrawnAt == date)
        #expect(saved.note == "partial")
    }
}

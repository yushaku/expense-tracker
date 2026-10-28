import Foundation
import SwiftData
import Testing

@testable import MonMon

/// `CashBalanceSummary.balances` replaced one `available(for:)` call per
/// account per use. These pin that it gives exactly the same figures, and that
/// the allocation figures built on it did not move.
@Suite("Cash balances in one pass")
@MainActor
struct CashBalancesParityTests {
    private let date = Date(timeIntervalSince1970: 1_700_000_000)

    private struct Ledger {
        var accounts: [CashAccount]
        var deposits: [SavingsDeposit]
        var holdings: [FundHolding]
        var withdrawals: [SavingsWithdrawal]
        var transactions: [MoneyTransaction]
        var transfers: [AccountTransfer]
        var debts: [Debt]
        var payments: [DebtPayment]
        var sales: [FundSale]
        var instruments: [FundInstrument]
    }

    /// Every kind of record that moves an account, including the awkward
    /// ones: a transfer naming the same account at both ends, a debt with no
    /// account, a payment naming no debt, a swap, and records naming an
    /// account that is not in the list.
    private func ledger() -> Ledger {
        let wallet = account("Wallet", .normal, 2_000_000)
        let bank = account("Bank", .normal, 50_000_000)
        let card = account("Card", .credit, -1_500_000)
        let stranger = UUID()

        let instrument = FundTestFactory.instrument(pricePerUnit: 60_000)
        let gold = FundTestFactory.instrument(symbol: "SJC", kind: .gold, pricePerUnit: 9_000_000)
        let holding = FundTestFactory.holding(
            in: instrument, units: 100, averageCostPerUnit: 50_000, sourceAccountID: bank.id)
        let goldHolding = FundTestFactory.holding(
            in: gold, units: 1, averageCostPerUnit: 8_000_000, sourceAccountID: wallet.id)
        let unlinkedHolding = FundTestFactory.holding(
            in: instrument, units: 10, averageCostPerUnit: 50_000)

        let deposit = SavingsDeposit(
            id: UUID(), name: "Term", principal: 10_000_000, annualInterestRate: 5,
            termMonths: 6, openedAt: date, currencyCode: VNDCurrency.code, createdAt: date,
            sourceAccountID: bank.id)
        let orphanDeposit = SavingsDeposit(
            id: UUID(), name: "Old", principal: 3_000_000, annualInterestRate: 4,
            termMonths: 3, openedAt: date, currencyCode: VNDCurrency.code, createdAt: date)
        let withdrawal = SavingsWithdrawal(
            id: UUID(), depositID: deposit.id, principal: 4_000_000, amountReceived: 4_100_000,
            destinationAccountID: wallet.id, withdrawnAt: date, createdAt: date)

        let borrowed = Debt(
            id: UUID(), counterparty: "Minh", direction: .borrowed, principal: 5_000_000,
            annualInterestRate: 0, openedAt: date, dueDate: nil, accountID: wallet.id,
            note: "", currencyCode: VNDCurrency.code, createdAt: date)
        let lent = Debt(
            id: UUID(), counterparty: "Lan", direction: .lent, principal: 2_000_000,
            annualInterestRate: 0, openedAt: date, dueDate: nil, accountID: bank.id,
            note: "", currencyCode: VNDCurrency.code, createdAt: date)
        let unlinkedDebt = Debt(
            id: UUID(), counterparty: "Ba", direction: .borrowed, principal: 700_000,
            annualInterestRate: 0, openedAt: date, dueDate: nil, accountID: nil,
            note: "", currencyCode: VNDCurrency.code, createdAt: date)

        let payments = [
            payment(debtID: borrowed.id, amount: 1_000_000, accountID: bank.id),
            payment(debtID: lent.id, amount: 500_000, accountID: wallet.id),
            payment(debtID: nil, amount: 900_000, accountID: wallet.id),
            payment(debtID: UUID(), amount: 300_000, accountID: card.id),
        ]

        let sale = FundSale(
            id: UUID(), holdingID: holding.id, units: 20, pricePerUnit: 60_000, fee: 5_000,
            proceedsAccountID: card.id, soldAt: date, createdAt: date)
        let swap = FundSale(
            id: UUID(), holdingID: holding.id, units: 5, pricePerUnit: 60_000,
            proceedsAccountID: wallet.id, soldAt: date, swapHoldingID: goldHolding.id,
            createdAt: date)

        let transactions = [
            transaction(.expense, 150_000, wallet.id),
            transaction(.income, 12_000_000, bank.id),
            transaction(.expense, 2_300_000, card.id),
            transaction(.expense, 99_999, stranger),
            transaction(.income, Decimal(string: "1234.5")!, wallet.id),
        ]
        let transfers = [
            transfer(3_000_000, from: bank.id, to: wallet.id),
            transfer(1_800_000, from: bank.id, to: card.id),
            transfer(250_000, from: wallet.id, to: wallet.id),
            transfer(400_000, from: stranger, to: wallet.id),
        ]

        return Ledger(
            accounts: [wallet, bank, card],
            deposits: [deposit, orphanDeposit],
            holdings: [holding, goldHolding, unlinkedHolding],
            withdrawals: [withdrawal],
            transactions: transactions,
            transfers: transfers,
            debts: [borrowed, lent, unlinkedDebt],
            payments: payments,
            sales: [sale, swap],
            instruments: [instrument, gold]
        )
    }

    private func oldAvailable(_ account: CashAccount, in l: Ledger) -> Decimal {
        CashBalanceSummary.available(
            for: account, deposits: l.deposits, holdings: l.holdings,
            withdrawals: l.withdrawals, transactions: l.transactions, transfers: l.transfers,
            debts: l.debts, payments: l.payments, sales: l.sales)
    }

    private func balances(_ l: Ledger) -> [UUID: Decimal] {
        CashBalanceSummary.balances(
            of: l.accounts, deposits: l.deposits, holdings: l.holdings,
            withdrawals: l.withdrawals, transactions: l.transactions, transfers: l.transfers,
            debts: l.debts, payments: l.payments, sales: l.sales)
    }

    @Test("Every account's balance matches available(for:)")
    func balancesMatchPerAccountFunction() {
        let l = ledger()
        let all = balances(l)

        #expect(all.count == l.accounts.count)
        for account in l.accounts {
            #expect(all[account.id] == oldAvailable(account, in: l))
        }
    }

    @Test("Overdrawn and positive totals match the per-account sums")
    func allocationTotalsMatch() {
        let l = ledger()
        let all = balances(l)
        let old = l.accounts.map { oldAvailable($0, in: l) }

        let positive = old.filter { $0 > 0 }.reduce(Decimal.zero, +)
        let overdrawn = old.filter { $0 < 0 }.reduce(Decimal.zero) { $0 - $1 }

        #expect(old.contains { $0 < 0 }, "The fixture should overdraw one account")
        #expect(AssetAllocation.positiveCash(in: all) == positive)
        #expect(AssetAllocation.overdraft(in: all) == overdrawn)
    }

    @Test("Ring and liability slices from shared balances match the ledger overloads")
    func slicesMatch() {
        let l = ledger()
        let all = balances(l)

        let fromLedger = AssetAllocation.slices(
            accounts: l.accounts, deposits: l.deposits, withdrawals: l.withdrawals,
            holdings: l.holdings, instruments: l.instruments, transactions: l.transactions,
            transfers: l.transfers, debts: l.debts, payments: l.payments, sales: l.sales)
        let fromBalances = AssetAllocation.slices(
            cashBalances: all, deposits: l.deposits, withdrawals: l.withdrawals,
            holdings: l.holdings, instruments: l.instruments, debts: l.debts,
            payments: l.payments, sales: l.sales)
        #expect(fromLedger == fromBalances)
        #expect(
            fromLedger.first { $0.kind == .cash }?.amount
                == l.accounts.map { oldAvailable($0, in: l) }.filter { $0 > 0 }
                .reduce(Decimal.zero, +))

        let liabilities = AssetAllocation.liabilitySlices(
            accounts: l.accounts, deposits: l.deposits, withdrawals: l.withdrawals,
            holdings: l.holdings, transactions: l.transactions, transfers: l.transfers,
            debts: l.debts, payments: l.payments, sales: l.sales)
        #expect(
            liabilities
                == AssetAllocation.liabilitySlices(
                    cashBalances: all, debts: l.debts, payments: l.payments))

        let accountSlices = AccountBalanceAllocation.slices(accounts: l.accounts, balances: all)
        let expected = l.accounts
            .map { ($0.id, oldAvailable($0, in: l)) }
            .filter { $0.1 > 0 }
            .sorted { $0.1 > $1.1 }
        #expect(accountSlices.map(\.accountID) == expected.map(\.0))
        #expect(accountSlices.map(\.amount) == expected.map(\.1))
    }

    @Test("The editors' per-account fetch matches available(for:) over whole tables")
    func fetchedBalanceMatches() throws {
        let l = ledger()
        let container = try ModelContainer(
            for: Schema(MonMonSchema.models),
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = ModelContext(container)
        l.accounts.forEach(context.insert)
        l.deposits.forEach(context.insert)
        l.holdings.forEach(context.insert)
        l.withdrawals.forEach(context.insert)
        l.transactions.forEach(context.insert)
        l.transfers.forEach(context.insert)
        l.debts.forEach(context.insert)
        l.payments.forEach(context.insert)
        l.sales.forEach(context.insert)
        l.instruments.forEach(context.insert)
        try context.save()

        for account in l.accounts {
            #expect(
                CashBalanceFetch.available(for: account, in: context)
                    == oldAvailable(account, in: l))
        }
    }

    @Test("An account with no records keeps its opening balance")
    func emptyLedger() {
        let wallet = account("Wallet", .normal, 123_456)
        let all = CashBalanceSummary.balances(
            of: [wallet], deposits: [], holdings: [], withdrawals: [], transactions: [],
            transfers: [], debts: [], payments: [], sales: [])
        #expect(all == [wallet.id: 123_456])
    }

    // MARK: - Fixtures

    private func account(_ name: String, _ kind: CashAccountKind, _ opening: Decimal)
        -> CashAccount
    {
        CashAccount(
            id: UUID(), name: name, kind: kind, openingBalance: opening,
            currencyCode: VNDCurrency.code, createdAt: date)
    }

    private func transaction(_ kind: TransactionKind, _ amount: Decimal, _ accountID: UUID)
        -> MoneyTransaction
    {
        MoneyTransaction(
            id: UUID(), kind: kind, amount: amount, occurredAt: date, note: "",
            accountID: accountID, categoryID: nil, sourceRuleID: nil,
            currencyCode: VNDCurrency.code, createdAt: date)
    }

    private func transfer(_ amount: Decimal, from source: UUID, to destination: UUID)
        -> AccountTransfer
    {
        AccountTransfer(
            id: UUID(), amount: amount, occurredAt: date, note: "",
            sourceAccountID: source, destinationAccountID: destination,
            currencyCode: VNDCurrency.code, createdAt: date)
    }

    private func payment(debtID: UUID?, amount: Decimal, accountID: UUID) -> DebtPayment {
        DebtPayment(
            id: UUID(), debtID: debtID, amount: amount, occurredAt: date,
            accountID: accountID, note: "", currencyCode: VNDCurrency.code, createdAt: date)
    }
}

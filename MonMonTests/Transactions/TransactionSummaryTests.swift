import Foundation
import Testing

@testable import MonMon

@Suite("Transaction summary")
struct TransactionSummaryTests {
    private let createdAt = Date(timeIntervalSince1970: 1_700_000_000)

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        let components = DateComponents(year: year, month: month, day: day)
        return TransactionPeriod.calendar.date(from: components) ?? .distantPast
    }

    private func makeAccount(openingBalance: Decimal = 0) -> CashAccount {
        CashAccount(
            id: UUID(),
            name: "Wallet",
            kind: .normal,
            openingBalance: openingBalance,
            currencyCode: VNDCurrency.code,
            createdAt: createdAt
        )
    }

    private func makeTransaction(
        kind: TransactionKind,
        amount: Decimal,
        accountID: UUID,
        occurredAt: Date? = nil,
        categoryID: UUID? = nil
    ) -> MoneyTransaction {
        MoneyTransaction(
            id: UUID(),
            kind: kind,
            amount: amount,
            occurredAt: occurredAt ?? createdAt,
            note: "",
            accountID: accountID,
            categoryID: categoryID,
            sourceRuleID: nil,
            currencyCode: VNDCurrency.code,
            createdAt: createdAt
        )
    }

    @Test("No transactions total to zero")
    func emptyTotalsAreZero() {
        #expect(TransactionSummary.totalIncome(of: []) == 0)
        #expect(TransactionSummary.totalExpense(of: []) == 0)
        #expect(TransactionSummary.net(of: []) == 0)
    }

    @Test("Income and expense are totalled separately and netted")
    func totalsSplitByKind() {
        let account = makeAccount()
        let transactions = [
            makeTransaction(kind: .income, amount: 5_000_000, accountID: account.id),
            makeTransaction(kind: .expense, amount: 200_000, accountID: account.id),
            makeTransaction(kind: .expense, amount: 300_000, accountID: account.id),
        ]

        #expect(TransactionSummary.totalIncome(of: transactions) == 5_000_000)
        #expect(TransactionSummary.totalExpense(of: transactions) == 500_000)
        #expect(TransactionSummary.net(of: transactions) == 4_500_000)
    }

    @Test("Net flow counts only the transactions of one account")
    func netFlowIsPerAccount() {
        let wallet = makeAccount()
        let bank = makeAccount()
        let transactions = [
            makeTransaction(kind: .income, amount: 1_000_000, accountID: wallet.id),
            makeTransaction(kind: .expense, amount: 400_000, accountID: wallet.id),
            makeTransaction(kind: .expense, amount: 900_000, accountID: bank.id),
        ]

        #expect(TransactionSummary.netFlow(for: wallet, transactions: transactions) == 600_000)
        #expect(TransactionSummary.netFlow(for: bank, transactions: transactions) == -900_000)
    }

    @Test("An account with no transactions has no flow")
    func untouchedAccountHasNoFlow() {
        let wallet = makeAccount()
        let bank = makeAccount()
        let transactions = [
            makeTransaction(kind: .income, amount: 1_000_000, accountID: wallet.id)
        ]

        #expect(TransactionSummary.netFlow(for: bank, transactions: transactions) == 0)
        #expect(TransactionSummary.count(for: bank, transactions: transactions) == 0)
        #expect(TransactionSummary.count(for: wallet, transactions: transactions) == 1)
    }

    @Test("Filtering by month keeps only that month's transactions")
    func monthFilterSelectsOneMonth() {
        let account = makeAccount()
        let transactions = [
            makeTransaction(
                kind: .expense,
                amount: 100_000,
                accountID: account.id,
                occurredAt: date(2026, 7, 31)
            ),
            makeTransaction(
                kind: .expense,
                amount: 200_000,
                accountID: account.id,
                occurredAt: date(2026, 8, 1)
            ),
            makeTransaction(
                kind: .income,
                amount: 900_000,
                accountID: account.id,
                occurredAt: date(2026, 8, 31)
            ),
            makeTransaction(
                kind: .expense,
                amount: 300_000,
                accountID: account.id,
                occurredAt: date(2026, 9, 1)
            ),
        ]

        let august = TransactionSummary.inRange(
            .month(containing: date(2026, 8, 15)),
            transactions: transactions
        )

        #expect(august.count == 2)
        #expect(TransactionSummary.net(of: august) == 700_000)
    }

    @Test("Category use is counted by identifier")
    func categoryUseIsCounted() {
        let account = makeAccount()
        let food = TransactionCategory(
            id: UUID(),
            name: "Food",
            kind: .expense,
            symbolName: CategoryPalette.defaultSymbolName,
            colorName: CategoryPalette.defaultColorName,
            createdAt: createdAt
        )
        let transactions = [
            makeTransaction(
                kind: .expense,
                amount: 100_000,
                accountID: account.id,
                categoryID: food.id
            ),
            makeTransaction(kind: .expense, amount: 200_000, accountID: account.id),
        ]

        #expect(TransactionSummary.count(for: food, transactions: transactions) == 1)
    }

    @Test("Category usage counts every category in one pass, skipping uncategorized")
    func countsByCategory() {
        let account = makeAccount()
        let food = UUID()
        let rent = UUID()
        let transactions = [
            makeTransaction(kind: .expense, amount: 1, accountID: account.id, categoryID: food),
            makeTransaction(kind: .expense, amount: 2, accountID: account.id, categoryID: rent),
            makeTransaction(kind: .expense, amount: 3, accountID: account.id, categoryID: food),
            makeTransaction(kind: .income, amount: 4, accountID: account.id),
        ]

        let counts = TransactionSummary.countsByCategory(transactions)

        #expect(counts == [food: 2, rent: 1])
        for id in [food, rent] {
            let category = TransactionCategory(
                id: id, name: "", kind: .expense, symbolName: "cart", colorName: "blue",
                createdAt: createdAt
            )
            #expect(
                counts[id] == TransactionSummary.count(for: category, transactions: transactions))
        }
    }

    @Test("No transactions make no day groups")
    func emptyGroupsAreEmpty() {
        #expect(TransactionSummary.byDay([]).isEmpty)
    }

    @Test("Transactions group by calendar day, newest day first")
    func daysGroupNewestFirst() {
        let account = makeAccount()
        let older = makeTransaction(
            kind: .expense,
            amount: 100_000,
            accountID: account.id,
            occurredAt: date(2024, 8, 10)
        )
        let sameDay = makeTransaction(
            kind: .income,
            amount: 500_000,
            accountID: account.id,
            occurredAt: date(2024, 8, 12).addingTimeInterval(3_600)
        )
        let newer = makeTransaction(
            kind: .expense,
            amount: 200_000,
            accountID: account.id,
            occurredAt: date(2024, 8, 12)
        )

        let groups = TransactionSummary.byDay([sameDay, newer, older])

        #expect(groups.count == 2)
        #expect(groups[0].day == date(2024, 8, 12))
        #expect(groups[1].day == date(2024, 8, 10))
        #expect(groups[0].transactions.count == 2)
        #expect(groups[1].transactions.count == 1)
    }

    @Test("A day keeps the order it was handed in")
    func dayKeepsIncomingOrder() {
        let account = makeAccount()
        let first = makeTransaction(
            kind: .expense,
            amount: 100_000,
            accountID: account.id,
            occurredAt: date(2024, 8, 12)
        )
        let second = makeTransaction(
            kind: .expense,
            amount: 200_000,
            accountID: account.id,
            occurredAt: date(2024, 8, 12)
        )

        let groups = TransactionSummary.byDay([first, second])

        #expect(groups.count == 1)
        #expect(groups[0].transactions.map(\.id) == [first.id, second.id])
    }

    @Test("A day nets its own income against its own expense")
    func dayNetsItsOwnTransactions() {
        let account = makeAccount()
        let groups = TransactionSummary.byDay([
            makeTransaction(
                kind: .income,
                amount: 500_000,
                accountID: account.id,
                occurredAt: date(2024, 8, 12)
            ),
            makeTransaction(
                kind: .expense,
                amount: 200_000,
                accountID: account.id,
                occurredAt: date(2024, 8, 12)
            ),
            makeTransaction(
                kind: .expense,
                amount: 900_000,
                accountID: account.id,
                occurredAt: date(2024, 8, 10)
            ),
        ])

        #expect(groups[0].net == 300_000)
        #expect(groups[1].net == -900_000)
    }

    @Test("The all filter keeps every transaction")
    func allFilterKeepsEverything() {
        let account = makeAccount()
        let transactions = [
            makeTransaction(kind: .income, amount: 500_000, accountID: account.id),
            makeTransaction(kind: .expense, amount: 200_000, accountID: account.id),
        ]

        #expect(
            TransactionSummary.matching(.all, transactions: transactions).count == 2
        )
    }

    @Test("A direction filter keeps only that direction")
    func directionFilterKeepsOneKind() {
        let account = makeAccount()
        let salary = makeTransaction(kind: .income, amount: 500_000, accountID: account.id)
        let transactions = [
            salary,
            makeTransaction(kind: .expense, amount: 200_000, accountID: account.id),
        ]

        let income = TransactionSummary.matching(.income, transactions: transactions)
        let expense = TransactionSummary.matching(.expense, transactions: transactions)

        #expect(income.map(\.id) == [salary.id])
        #expect(expense.count == 1)
        #expect(expense.first?.kind == .expense)
    }

    @Test("The running total adds each day to the ones before it")
    func runningNetAccumulatesForward() {
        let account = makeAccount()
        let transactions = [
            makeTransaction(
                kind: .expense,
                amount: 100_000,
                accountID: account.id,
                occurredAt: date(2026, 1, 3)
            ),
            makeTransaction(
                kind: .income,
                amount: 1_000_000,
                accountID: account.id,
                occurredAt: date(2026, 1, 1)
            ),
            makeTransaction(
                kind: .expense,
                amount: 400_000,
                accountID: account.id,
                occurredAt: date(2026, 1, 2)
            ),
        ]

        let points = TransactionSummary.runningNet(transactions)

        #expect(points.map(\.day) == [date(2026, 1, 1), date(2026, 1, 2), date(2026, 1, 3)])
        #expect(points.map(\.net) == [1_000_000, 600_000, 500_000])
    }
}

@Suite("Unified transaction history")
struct TransactionHistoryTests {
    private let day =
        TransactionPeriod.calendar.date(from: DateComponents(year: 2026, month: 9, day: 10))
        ?? .distantPast
    private let source = UUID()
    private let destination = UUID()

    private func transfer(at date: Date, id: UUID = UUID()) -> AccountTransfer {
        AccountTransfer(
            id: id, amount: 150_000, occurredAt: date, note: "Cash for lunch",
            sourceAccountID: source, destinationAccountID: destination,
            currencyCode: VNDCurrency.code, createdAt: date
        )
    }

    @Test("Transfers interleave by time, including transfer-only days, without changing net")
    func mixedHistory() {
        let income = MoneyTransaction.preview(
            kind: .income, amount: 500_000, accountID: source, categoryID: nil)
        income.occurredAt = day.addingTimeInterval(100)
        let older = transfer(at: day.addingTimeInterval(50))
        let newer = transfer(at: day.addingTimeInterval(200))
        let tomorrow = transfer(at: day.addingTimeInterval(86_400))
        let groups = TransactionHistory.byDay(
            transactions: [income], transfers: [older, tomorrow, newer])
        #expect(groups.count == 2)
        #expect(groups[0].entries.count == 1)
        #expect(groups[0].net == 0)
        #expect(
            groups[1].entries.map(\.id) == [
                TransactionHistoryEntry.transfer(newer).id,
                TransactionHistoryEntry.transaction(income).id,
                TransactionHistoryEntry.transfer(older).id,
            ])
        #expect(groups[1].net == 500_000)
    }

    @Test("Typed IDs do not collide and equal timestamps have deterministic ordering")
    func stableIdentity() {
        let income = MoneyTransaction.preview(
            kind: .income, amount: 500_000, accountID: source, categoryID: nil)
        income.occurredAt = day
        income.createdAt = day
        let moved = transfer(at: day, id: income.id)
        let a = TransactionHistoryEntry.transaction(income)
        let b = TransactionHistoryEntry.transfer(moved)
        #expect(a.id != b.id)
        let first = TransactionHistory.byDay(transactions: [income], transfers: [moved])
        let second = TransactionHistory.byDay(transactions: [income], transfers: [moved])
        #expect(first[0].entries.map(\.id) == second[0].entries.map(\.id))
        #expect(TransactionHistory.byDay(transactions: [], transfers: []).isEmpty)
    }

    @Test("Transfer search respects period, both accounts, note, amount and accent folding")
    func transferSearch() {
        let moved = transfer(at: day)
        let outside = transfer(at: day.addingTimeInterval(86_400))
        var query = TransactionQuery(range: .day(containing: day))
        let names = [source: "Ngân hàng", destination: "Wallet"]
        func results() -> [UUID] {
            TransactionSearch.transferResults(
                of: query, transfers: [moved, outside], accountNames: names
            ).map(\.id)
        }
        #expect(results() == [moved.id])
        query.accountIDs = [source]
        #expect(results() == [moved.id])
        query.accountIDs = [destination]
        #expect(results() == [moved.id])
        query.accountIDs = [UUID()]
        #expect(results().isEmpty)
        query.accountIDs = []
        query.text = "NGAN wallet lunch 150"
        #expect(results() == [moved.id])
        query.text = "missing"
        #expect(results().isEmpty)
        query.text = "transfer"
        #expect(results() == [moved.id])
        query.filter = .income
        #expect(results().isEmpty)
        query.filter = .expense
        #expect(results().isEmpty)
        query.filter = .all
        query.categoryIDs = [UUID()]
        #expect(results().isEmpty)
    }
}

@Suite("Transaction row lookup")
struct TransactionRowLookupTests {
    private let createdAt = Date(timeIntervalSince1970: 1_700_000_000)

    private func category(id: UUID, name: String) -> TransactionCategory {
        TransactionCategory(
            id: id, name: name, kind: .expense, symbolName: "cart",
            colorName: "blue", createdAt: createdAt
        )
    }

    private func trip(id: UUID, name: String) -> TripWorkspace {
        TripWorkspace(
            id: id, sourceGoalID: nil, name: name, budgetAmount: 1_000_000,
            fundingJarID: nil, symbolName: "airplane", colorName: "blue",
            status: .active, startedAt: createdAt, completedAt: nil, createdAt: createdAt
        )
    }

    @Test("Rows resolve their category, account and trip by id")
    func resolvesByID() {
        let food = category(id: UUID(), name: "Food")
        let wallet = CashAccount.preview(name: "Wallet", kind: .normal, openingBalance: 0)
        let holiday = trip(id: UUID(), name: "Đà Lạt")
        let transaction = MoneyTransaction.preview(
            kind: .expense, amount: 50_000, accountID: wallet.id, categoryID: food.id)
        transaction.tripWorkspaceID = holiday.id

        let lookup = TransactionRowLookup(
            categories: [food], accounts: [wallet], trips: [holiday])

        #expect(lookup.category(for: transaction) === food)
        #expect(lookup.account(transaction.accountID) === wallet)
        #expect(lookup.tripName(for: transaction) == "Đà Lạt")
    }

    @Test("Missing links resolve to nothing")
    func missingLinksAreNil() {
        let transaction = MoneyTransaction.preview(
            kind: .expense, amount: 50_000, accountID: UUID(), categoryID: nil)
        transaction.tripWorkspaceID = UUID()

        let lookup = TransactionRowLookup(
            categories: [category(id: UUID(), name: "Food")], accounts: [], trips: [])

        #expect(lookup.category(for: transaction) == nil)
        #expect(lookup.account(transaction.accountID) == nil)
        #expect(lookup.tripName(for: transaction) == nil)
    }

    @Test("A duplicated id resolves to the first record, as a linear search did")
    func firstDuplicateWins() {
        let id = UUID()
        let first = category(id: id, name: "First")
        let second = category(id: id, name: "Second")
        let transaction = MoneyTransaction.preview(
            kind: .expense, amount: 50_000, accountID: UUID(), categoryID: id)

        let lookup = TransactionRowLookup(categories: [first, second], accounts: [], trips: [])

        #expect(lookup.category(for: transaction) === first)
    }
}

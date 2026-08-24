import Foundation
import SwiftData
import Testing

@testable import MonMon

@Suite("Duplicate reconciler")
struct DuplicateReconcilerTests {
    private struct Row {
        let id: UUID
        let key: String
        let createdAt: Date
    }

    private func merges(_ rows: [Row]) -> [DuplicateReconciler.Merge<Row>] {
        DuplicateReconciler.merges(
            in: rows,
            key: \.key,
            createdAt: \.createdAt,
            id: \.id
        )
    }

    private let day0 = Date(timeIntervalSince1970: 1_700_000_000)
    private var day1: Date { day0.addingTimeInterval(86_400) }

    @Test("Nothing duplicated reports nothing")
    func nothingDuplicated() {
        let rows = [
            Row(id: UUID(), key: "a", createdAt: day0),
            Row(id: UUID(), key: "b", createdAt: day0),
        ]

        #expect(merges(rows).isEmpty)
    }

    @Test("The oldest row survives")
    func oldestSurvives() {
        let older = Row(id: UUID(), key: "a", createdAt: day0)
        let newer = Row(id: UUID(), key: "a", createdAt: day1)

        let result = merges([newer, older])

        #expect(result.count == 1)
        #expect(result.first?.survivor.id == older.id)
        #expect(result.first?.duplicates.map(\.id) == [newer.id])
    }

    /// Two devices reconciling the same set have to reach the same answer. If
    /// they disagreed, each would delete what the other kept and the row would
    /// be erased entirely — so identical timestamps break to the smaller id
    /// rather than to whatever order the fetch happened to return.
    @Test("Identical timestamps break to the smaller id, in either input order")
    func tiesBreakDeterministically() throws {
        let low = Row(
            id: try #require(UUID(uuidString: "00000000-0000-0000-0000-00000000000A")),
            key: "a",
            createdAt: day0
        )
        let high = Row(
            id: try #require(UUID(uuidString: "FFFFFFFF-0000-0000-0000-00000000000B")),
            key: "a",
            createdAt: day0
        )

        #expect(merges([low, high]).first?.survivor.id == low.id)
        #expect(merges([high, low]).first?.survivor.id == low.id)
    }

    @Test("Three of a kind leave one survivor and two duplicates")
    func threeOfAKind() {
        let rows = [
            Row(id: UUID(), key: "a", createdAt: day1),
            Row(id: UUID(), key: "a", createdAt: day0),
            Row(id: UUID(), key: "a", createdAt: day1),
        ]

        let result = merges(rows)

        #expect(result.count == 1)
        #expect(result.first?.duplicates.count == 2)
    }

    @Test("An empty key is skipped rather than grouped")
    func emptyKeyIsSkipped() {
        let rows = [
            Row(id: UUID(), key: "", createdAt: day0),
            Row(id: UUID(), key: "", createdAt: day1),
        ]

        #expect(merges(rows).isEmpty)
    }
}

@MainActor
@Suite("Store reconciler")
struct StoreReconcilerTests {
    private let day0 = Date(timeIntervalSince1970: 1_700_000_000)
    private var day1: Date { day0.addingTimeInterval(86_400) }

    private func makeContainer() throws -> ModelContainer {
        try ModelContainer(
            for: Schema(MonMonSchema.models),
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    private func category(
        _ name: String,
        kind: TransactionKind = .expense,
        createdAt: Date
    ) -> TransactionCategory {
        TransactionCategory(
            id: UUID(),
            name: name,
            kind: kind,
            symbolName: CategoryPalette.defaultSymbolName,
            colorName: CategoryPalette.defaultColorName,
            createdAt: createdAt
        )
    }

    @Test("A clean store is left alone")
    func cleanStoreIsLeftAlone() throws {
        let container = try makeContainer()
        let context = container.mainContext
        context.insert(category("Food", createdAt: day0))
        context.insert(category("Transport", createdAt: day0))
        try context.save()

        let report = try StoreReconciler.reconcile(in: context)

        #expect(report.isEmpty)
        #expect(try context.fetchCount(FetchDescriptor<TransactionCategory>()) == 2)
    }

    /// The case this exists for: a second device seeds its own starter set
    /// before the first device's set arrives.
    @Test("Two seeded category sets fold into one")
    func twoSeededSetsFoldIntoOne() throws {
        let container = try makeContainer()
        let context = container.mainContext
        for template in CategorySeed.makeCategories(createdAt: day0) {
            context.insert(template)
        }
        for template in CategorySeed.makeCategories(createdAt: day1) {
            context.insert(template)
        }
        try context.save()

        let seeded = CategorySeed.templates.count
        #expect(try context.fetchCount(FetchDescriptor<TransactionCategory>()) == seeded * 2)

        let report = try StoreReconciler.reconcile(in: context)

        #expect(report.categories == seeded)
        #expect(try context.fetchCount(FetchDescriptor<TransactionCategory>()) == seeded)
    }

    @Test("Case and surrounding space do not make a second category")
    func caseAndSpaceStillMatch() throws {
        let container = try makeContainer()
        let context = container.mainContext
        context.insert(category("Food", createdAt: day0))
        context.insert(category("  food  ", createdAt: day1))
        try context.save()

        let report = try StoreReconciler.reconcile(in: context)

        #expect(report.categories == 1)
    }

    @Test("One name under two kinds is two categories")
    func sameNameDifferentKindIsNotADuplicate() throws {
        let container = try makeContainer()
        let context = container.mainContext
        context.insert(category("Interest", kind: .expense, createdAt: day0))
        context.insert(category("Interest", kind: .income, createdAt: day1))
        try context.save()

        let report = try StoreReconciler.reconcile(in: context)

        #expect(report.isEmpty)
        #expect(try context.fetchCount(FetchDescriptor<TransactionCategory>()) == 2)
    }

    /// Folding must not lose history. A transaction filed under the duplicate
    /// has to come out filed under the survivor.
    @Test("A transaction under a folded category moves to the survivor")
    func transactionMovesToTheSurvivor() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let survivor = category("Food", createdAt: day0)
        let duplicate = category("Food", createdAt: day1)
        context.insert(survivor)
        context.insert(duplicate)

        let transaction = MoneyTransaction(
            id: UUID(),
            kind: .expense,
            amount: 50_000,
            occurredAt: day1,
            note: "",
            accountID: AccountSeed.unassignedID,
            categoryID: duplicate.id,
            sourceRuleID: nil,
            currencyCode: VNDCurrency.code,
            createdAt: day1
        )
        context.insert(transaction)
        try context.save()

        let report = try StoreReconciler.reconcile(in: context)

        #expect(report.categories == 1)
        #expect(transaction.categoryID == survivor.id)
        #expect(
            TransactionSummary.count(for: survivor, transactions: [transaction]) == 1
        )
    }

    @Test("A position under a folded instrument moves to the survivor")
    func holdingMovesToTheSurvivor() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let survivor = FundTestFactory.instrument(pricePerUnit: 30_000)
        survivor.createdAt = day0
        let duplicate = FundTestFactory.instrument(pricePerUnit: 31_000)
        duplicate.createdAt = day1
        context.insert(survivor)
        context.insert(duplicate)

        let holding = FundTestFactory.holding(
            in: duplicate,
            units: 100,
            averageCostPerUnit: 20_000
        )
        context.insert(holding)
        try context.save()

        let report = try StoreReconciler.reconcile(in: context)

        #expect(report.instruments == 1)
        #expect(holding.instrumentID == survivor.id)
        // The position keeps its value rather than falling to nothing: it is
        // priced by the survivor now, not by a row that no longer exists.
        #expect(holding.marketValue(in: [survivor]) == 3_000_000)
    }

    @Test("Two different tickers are left alone")
    func differentTickersAreLeftAlone() throws {
        let container = try makeContainer()
        let context = container.mainContext
        context.insert(FundTestFactory.instrument(symbol: "VESAF", pricePerUnit: 30_000))
        context.insert(FundTestFactory.instrument(symbol: "VEOF", pricePerUnit: 20_000))
        try context.save()

        #expect(try StoreReconciler.reconcile(in: context).isEmpty)
    }

    /// Both devices seed the anchor, and both write the same fixed id.
    @Test("Two anchor accounts fold into one")
    func twoAnchorsFoldIntoOne() throws {
        let container = try makeContainer()
        let context = container.mainContext
        for createdAt in [day0, day1] {
            context.insert(
                CashAccount(
                    id: AccountSeed.unassignedID,
                    name: AccountSeed.unassignedName,
                    kind: .cash,
                    openingBalance: .zero,
                    currencyCode: VNDCurrency.code,
                    createdAt: createdAt
                )
            )
        }
        try context.save()

        let report = try StoreReconciler.reconcile(in: context)

        #expect(report.accounts == 1)
        let remaining = try context.fetch(FetchDescriptor<CashAccount>())
        #expect(remaining.count == 1)
        #expect(remaining.first?.createdAt == day0)
    }

    @Test("Distinct accounts are never folded together")
    func distinctAccountsSurvive() throws {
        let container = try makeContainer()
        let context = container.mainContext
        for name in ["Wallet", "Techcombank"] {
            context.insert(
                CashAccount(
                    id: UUID(),
                    name: name,
                    kind: .bank,
                    openingBalance: 1_000_000,
                    currencyCode: VNDCurrency.code,
                    createdAt: day0
                )
            )
        }
        try context.save()

        #expect(try StoreReconciler.reconcile(in: context).isEmpty)
        #expect(try context.fetchCount(FetchDescriptor<CashAccount>()) == 2)
    }

    /// This runs on every launch and every return to the foreground, so a
    /// second pass has to find nothing left to do.
    @Test("Reconciling twice changes nothing the second time")
    func reconcilingIsIdempotent() throws {
        let container = try makeContainer()
        let context = container.mainContext
        context.insert(category("Food", createdAt: day0))
        context.insert(category("Food", createdAt: day1))
        try context.save()

        #expect(try StoreReconciler.reconcile(in: context).categories == 1)
        #expect(try StoreReconciler.reconcile(in: context).isEmpty)
        #expect(try context.fetchCount(FetchDescriptor<TransactionCategory>()) == 1)
    }

    private func rule(categoryID: UUID?, createdAt: Date) -> RecurringRule {
        RecurringRule(
            id: UUID(),
            kind: .expense,
            amount: 8_000_000,
            note: "Rent",
            accountID: AccountSeed.unassignedID,
            categoryID: categoryID,
            currencyCode: VNDCurrency.code,
            frequency: .monthly,
            interval: 1,
            anchorDate: createdAt,
            endDate: nil,
            isPaused: false,
            lastGeneratedAt: nil,
            createdAt: createdAt
        )
    }

    private func generated(
        ruleID: UUID?,
        occurredAt: Date,
        createdAt: Date
    ) -> MoneyTransaction {
        MoneyTransaction(
            id: UUID(),
            kind: .expense,
            amount: 8_000_000,
            occurredAt: occurredAt,
            note: "Rent",
            accountID: AccountSeed.unassignedID,
            categoryID: nil,
            sourceRuleID: ruleID,
            currencyCode: VNDCurrency.code,
            createdAt: createdAt
        )
    }

    /// A rule files what it will record next, so it has to follow the survivor
    /// as well, or tomorrow's entry lands under a category that is gone.
    @Test("A rule under a folded category moves to the survivor")
    func ruleMovesToTheSurvivor() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let survivor = category("Food", createdAt: day0)
        let duplicate = category("Food", createdAt: day1)
        context.insert(survivor)
        context.insert(duplicate)

        let recurring = rule(categoryID: duplicate.id, createdAt: day1)
        context.insert(recurring)
        try context.save()

        let report = try StoreReconciler.reconcile(in: context)

        #expect(report.categories == 1)
        #expect(recurring.categoryID == survivor.id)
    }

    /// Two devices that had not met yet both generate the month's rent. The
    /// duplicate lands when synchronisation does, which is what this fold is for.
    @Test("Two entries from one rule on one day fold into the older")
    func duplicateGeneratedEntriesFold() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let recurring = rule(categoryID: nil, createdAt: day0)
        context.insert(recurring)
        let survivor = generated(ruleID: recurring.id, occurredAt: day0, createdAt: day0)
        context.insert(survivor)
        context.insert(generated(ruleID: recurring.id, occurredAt: day0, createdAt: day1))
        try context.save()

        let report = try StoreReconciler.reconcile(in: context)

        #expect(report.transactions == 1)

        let remaining = try context.fetch(FetchDescriptor<MoneyTransaction>())
        #expect(remaining.count == 1)
        #expect(remaining.first?.id == survivor.id)
    }

    @Test("One rule on two different days keeps both entries")
    func differentDaysFromOneRuleBothSurvive() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let recurring = rule(categoryID: nil, createdAt: day0)
        context.insert(recurring)
        context.insert(generated(ruleID: recurring.id, occurredAt: day0, createdAt: day0))
        context.insert(generated(ruleID: recurring.id, occurredAt: day1, createdAt: day1))
        try context.save()

        #expect(try StoreReconciler.reconcile(in: context).isEmpty)
        #expect(try context.fetchCount(FetchDescriptor<MoneyTransaction>()) == 2)
    }

    /// Two lunches on one day are two lunches.
    @Test("Hand-typed transactions on one day are never folded")
    func handTypedTransactionsAreNeverFolded() throws {
        let container = try makeContainer()
        let context = container.mainContext
        context.insert(generated(ruleID: nil, occurredAt: day0, createdAt: day0))
        context.insert(generated(ruleID: nil, occurredAt: day0, createdAt: day1))
        try context.save()

        #expect(try StoreReconciler.reconcile(in: context).isEmpty)
        #expect(try context.fetchCount(FetchDescriptor<MoneyTransaction>()) == 2)
    }

    @Test("Two rules falling on the same day keep both entries")
    func twoRulesOnOneDayBothSurvive() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let rent = rule(categoryID: nil, createdAt: day0)
        let gym = rule(categoryID: nil, createdAt: day0)
        context.insert(rent)
        context.insert(gym)
        context.insert(generated(ruleID: rent.id, occurredAt: day0, createdAt: day0))
        context.insert(generated(ruleID: gym.id, occurredAt: day0, createdAt: day0))
        try context.save()

        #expect(try StoreReconciler.reconcile(in: context).isEmpty)
        #expect(try context.fetchCount(FetchDescriptor<MoneyTransaction>()) == 2)
    }
}

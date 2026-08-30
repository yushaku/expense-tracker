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
    private let importA = String(repeating: "a", count: 64)
    private let importB = String(repeating: "b", count: 64)
    private let importC = String(repeating: "c", count: 64)

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
        #expect(holding.marketValue(in: [survivor], sales: []) == 3_000_000)
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
                    kind: .normal,
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

    @Test("Two copies of a seeded budget jar fold into one")
    func twoSeededBudgetJarsFoldIntoOne() throws {
        let container = try makeContainer()
        let context = container.mainContext
        for createdAt in [day0, day1] {
            context.insert(
                BudgetJar(
                    id: BudgetJarSeed.savingsID,
                    name: "Savings",
                    allocationPercent: 10,
                    role: .savings,
                    symbolName: "building.columns.fill",
                    colorName: "yellow",
                    createdAt: createdAt
                )
            )
        }
        try context.save()

        let report = try StoreReconciler.reconcile(in: context)

        #expect(report.budgetJars == 1)
        let remaining = try context.fetch(FetchDescriptor<BudgetJar>())
        #expect(remaining.count == 1)
        #expect(remaining.first?.createdAt == day0)
    }

    @Test("Two physical copies of one financial goal fold into one")
    func duplicateFinancialGoalsFoldIntoOne() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let goalID = UUID()
        for createdAt in [day0, day1] {
            context.insert(
                FinancialGoal(
                    id: goalID,
                    name: "Japan trip",
                    targetAmount: 100_000_000,
                    earmarkedAmount: 10_000_000,
                    targetDate: day1.addingTimeInterval(31_536_000),
                    monthlyContribution: 5_000_000,
                    fundingJarID: BudgetJarSeed.savingsID,
                    symbolName: "airplane",
                    colorName: "sky",
                    createdAt: createdAt
                )
            )
        }
        try context.save()

        let report = try StoreReconciler.reconcile(in: context)

        #expect(report.goals == 1)
        let remaining = try context.fetch(FetchDescriptor<FinancialGoal>())
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
                    kind: .normal,
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

    @Test("Two workspaces for one source goal fold and repoint Trip expenses")
    func duplicateTripWorkspacesFoldAndRepointExpenses() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let goalID = UUID()
        let survivor = tripWorkspace(sourceGoalID: goalID, createdAt: day0)
        let duplicate = tripWorkspace(sourceGoalID: goalID, createdAt: day1)
        let expense = generated(ruleID: nil, occurredAt: day1, createdAt: day1)
        expense.tripWorkspaceID = duplicate.id
        expense.budgetJarOverrideID = BudgetJarSeed.savingsID
        context.insert(survivor)
        context.insert(duplicate)
        context.insert(expense)
        try context.save()

        let report = try StoreReconciler.reconcile(in: context)

        #expect(report.trips == 1)
        #expect(try context.fetch(FetchDescriptor<TripWorkspace>()).map(\.id) == [survivor.id])
        #expect(expense.tripWorkspaceID == survivor.id)
        #expect(expense.budgetJarOverrideID == BudgetJarSeed.savingsID)
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

    private func tripWorkspace(sourceGoalID: UUID, createdAt: Date) -> TripWorkspace {
        TripWorkspace(
            id: UUID(),
            sourceGoalID: sourceGoalID,
            name: "Japan",
            budgetAmount: 10_000_000,
            fundingJarID: BudgetJarSeed.savingsID,
            symbolName: "airplane",
            colorName: "sky",
            status: .active,
            startedAt: createdAt,
            completedAt: nil,
            createdAt: createdAt
        )
    }

    private func generated(
        ruleID: UUID?,
        occurredAt: Date,
        createdAt: Date,
        sourceImportID: String? = nil,
        amount: Decimal = 8_000_000
    ) -> MoneyTransaction {
        MoneyTransaction(
            id: UUID(),
            kind: .expense,
            amount: amount,
            occurredAt: occurredAt,
            note: "Rent",
            accountID: AccountSeed.unassignedID,
            categoryID: nil,
            sourceRuleID: ruleID,
            currencyCode: VNDCurrency.code,
            createdAt: createdAt,
            sourceImportID: sourceImportID
        )
    }

    private func allocationJar() -> BudgetJar {
        BudgetJar(
            id: UUID(),
            name: "Savings",
            allocationPercent: 100,
            role: .savings,
            symbolName: "building.columns.fill",
            colorName: "yellow",
            createdAt: day0
        )
    }

    private func importedTransfer(
        createdAt: Date,
        sourceImportID: String? = nil,
        destinationImportID: String? = nil,
        amount: Decimal = 8_000_000,
        sourceAccountID: UUID = AccountSeed.unassignedID,
        destinationAccountID: UUID = UUID()
    ) -> AccountTransfer {
        AccountTransfer(
            id: UUID(),
            amount: amount,
            occurredAt: day0,
            note: "Synthetic transfer",
            sourceAccountID: sourceAccountID,
            destinationAccountID: destinationAccountID,
            currencyCode: VNDCurrency.code,
            createdAt: createdAt,
            sourceAccountImportID: sourceImportID,
            destinationAccountImportID: destinationImportID
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

    @Test("Folding generated income preserves a valid allocation snapshot")
    func generatedIncomeFoldPreservesSnapshot() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let recurring = rule(categoryID: nil, createdAt: day0)
        context.insert(recurring)
        let survivor = generated(ruleID: recurring.id, occurredAt: day0, createdAt: day0)
        survivor.kind = .income
        let duplicate = generated(ruleID: recurring.id, occurredAt: day0, createdAt: day1)
        duplicate.kind = .income
        try IncomeAllocationLifecycle.captureNew(
            on: duplicate,
            jars: [allocationJar()],
            capturedAt: day1
        )
        let expectedSnapshot = duplicate.incomeAllocationSnapshot
        context.insert(survivor)
        context.insert(duplicate)
        try context.save()

        _ = try StoreReconciler.reconcile(in: context)

        let transactions = try context.fetch(FetchDescriptor<MoneyTransaction>())
        let remaining = try #require(transactions.first)
        #expect(transactions.count == 1)
        #expect(remaining.id == survivor.id)
        #expect(remaining.incomeAllocationSnapshot == expectedSnapshot)
    }

    @Test("Folding duplicate expenses preserves Trip routing metadata")
    func generatedExpenseFoldPreservesTripRouting() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let recurring = rule(categoryID: nil, createdAt: day0)
        let survivor = generated(ruleID: recurring.id, occurredAt: day0, createdAt: day0)
        let duplicate = generated(ruleID: recurring.id, occurredAt: day0, createdAt: day1)
        duplicate.tripWorkspaceID = UUID()
        duplicate.budgetJarOverrideID = UUID()
        let expectedTripID = duplicate.tripWorkspaceID
        let expectedJarID = duplicate.budgetJarOverrideID
        context.insert(recurring)
        context.insert(survivor)
        context.insert(duplicate)
        try context.save()

        _ = try StoreReconciler.reconcile(in: context)

        #expect(survivor.tripWorkspaceID == expectedTripID)
        #expect(survivor.budgetJarOverrideID == expectedJarID)
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

    @Test("Imported transaction duplicates fold into the oldest record")
    func importedTransactionDuplicatesFold() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let survivor = generated(
            ruleID: nil,
            occurredAt: day0,
            createdAt: day0,
            sourceImportID: importA
        )
        let duplicate = generated(
            ruleID: nil,
            occurredAt: day0,
            createdAt: day1,
            sourceImportID: importA
        )
        duplicate.note = "Edited on another device"
        context.insert(duplicate)
        context.insert(survivor)
        try context.save()

        let report = try StoreReconciler.reconcile(in: context)

        #expect(report.transactions == 1)
        let remaining = try context.fetch(FetchDescriptor<MoneyTransaction>())
        #expect(remaining.map(\.id) == [survivor.id])
    }

    @Test("Invalid, recurring, and conflicting imported transactions stay independent")
    func unsafeImportedTransactionsAreNotFolded() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let firstRecurring = rule(categoryID: nil, createdAt: day0)
        let secondRecurring = rule(categoryID: nil, createdAt: day0)
        context.insert(firstRecurring)
        context.insert(secondRecurring)

        for transaction in [
            generated(
                ruleID: nil,
                occurredAt: day0,
                createdAt: day0,
                sourceImportID: "not-a-fingerprint"
            ),
            generated(
                ruleID: nil,
                occurredAt: day0,
                createdAt: day1,
                sourceImportID: "not-a-fingerprint"
            ),
            generated(
                ruleID: firstRecurring.id,
                occurredAt: day0,
                createdAt: day0,
                sourceImportID: importA
            ),
            generated(
                ruleID: secondRecurring.id,
                occurredAt: day0,
                createdAt: day1,
                sourceImportID: importA
            ),
            generated(
                ruleID: nil,
                occurredAt: day0,
                createdAt: day0,
                sourceImportID: importB,
                amount: 100_000
            ),
            generated(
                ruleID: nil,
                occurredAt: day0,
                createdAt: day1,
                sourceImportID: importB,
                amount: 200_000
            ),
        ] {
            context.insert(transaction)
        }
        try context.save()

        #expect(try StoreReconciler.reconcile(in: context).isEmpty)
        #expect(try context.fetchCount(FetchDescriptor<MoneyTransaction>()) == 6)
    }

    @Test("Same-side transfer duplicates fold and preserve opposite provenance")
    func sameSideTransferDuplicatesFold() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let destinationID = UUID()
        let survivor = importedTransfer(
            createdAt: day0,
            sourceImportID: importA,
            destinationAccountID: destinationID
        )
        let duplicate = importedTransfer(
            createdAt: day1,
            sourceImportID: importA,
            destinationImportID: importB,
            destinationAccountID: destinationID
        )
        context.insert(duplicate)
        context.insert(survivor)
        try context.save()

        let report = try StoreReconciler.reconcile(in: context)

        #expect(report.transfers == 1)
        let remaining = try context.fetch(FetchDescriptor<AccountTransfer>())
        #expect(remaining.map(\.id) == [survivor.id])
        #expect(remaining.first?.destinationAccountImportID == importB)
        #expect(try StoreReconciler.reconcile(in: context).isEmpty)
    }

    @Test("Destination-side transfer duplicates fold")
    func destinationSideTransferDuplicatesFold() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let sourceID = UUID()
        let destinationID = UUID()
        let survivor = importedTransfer(
            createdAt: day0,
            destinationImportID: importA,
            sourceAccountID: sourceID,
            destinationAccountID: destinationID
        )
        context.insert(survivor)
        context.insert(
            importedTransfer(
                createdAt: day1,
                destinationImportID: importA,
                sourceAccountID: sourceID,
                destinationAccountID: destinationID
            )
        )
        try context.save()

        #expect(try StoreReconciler.reconcile(in: context).transfers == 1)
        let remaining = try context.fetch(FetchDescriptor<AccountTransfer>())
        #expect(remaining.map(\.id) == [survivor.id])
    }

    @Test("Opposite-side, nil, and conflicting transfers are not folded")
    func unsafeTransfersAreNotFolded() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let sourceID = UUID()
        let destinationID = UUID()
        let conflictSourceID = UUID()
        let conflictDestinationID = UUID()

        for transfer in [
            importedTransfer(
                createdAt: day0,
                sourceImportID: importA,
                sourceAccountID: sourceID,
                destinationAccountID: destinationID
            ),
            importedTransfer(
                createdAt: day1,
                destinationImportID: importA,
                sourceAccountID: sourceID,
                destinationAccountID: destinationID
            ),
            importedTransfer(
                createdAt: day0,
                sourceAccountID: sourceID,
                destinationAccountID: destinationID
            ),
            importedTransfer(
                createdAt: day1,
                sourceAccountID: sourceID,
                destinationAccountID: destinationID
            ),
            importedTransfer(
                createdAt: day0,
                sourceImportID: importB,
                destinationImportID: importA,
                sourceAccountID: conflictSourceID,
                destinationAccountID: conflictDestinationID
            ),
            importedTransfer(
                createdAt: day1,
                sourceImportID: importB,
                destinationImportID: importC,
                sourceAccountID: conflictSourceID,
                destinationAccountID: conflictDestinationID
            ),
            importedTransfer(
                createdAt: day0,
                sourceImportID: "not-a-fingerprint",
                amount: 7_000_000,
                sourceAccountID: sourceID,
                destinationAccountID: destinationID
            ),
            importedTransfer(
                createdAt: day1,
                sourceImportID: "not-a-fingerprint",
                amount: 7_000_000,
                sourceAccountID: sourceID,
                destinationAccountID: destinationID
            ),
        ] {
            context.insert(transfer)
        }
        try context.save()

        #expect(try StoreReconciler.reconcile(in: context).isEmpty)
        #expect(try context.fetchCount(FetchDescriptor<AccountTransfer>()) == 8)
    }
}

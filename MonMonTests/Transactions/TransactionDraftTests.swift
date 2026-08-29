import Foundation
import Testing

@testable import MonMon

@Suite("Transaction draft validation")
struct TransactionDraftTests {
    private let occurredAt = Date(timeIntervalSince1970: 1_700_000_000)
    private let accountID = UUID()
    private let categoryID = UUID()

    private func makeDraft(
        kind: TransactionKind = .expense,
        amountText: String = "200.000",
        note: String = "",
        accountID: UUID? = nil,
        categoryID: UUID? = nil
    ) -> TransactionDraft {
        TransactionDraft(
            kind: kind,
            amountText: amountText,
            occurredAt: occurredAt,
            note: note,
            accountID: accountID ?? self.accountID,
            categoryID: categoryID ?? self.categoryID
        )
    }

    @Test("Missing preferences apply the seeded Food and Bank defaults")
    func missingPreferencesApplySeedDefaults() {
        let bank = CashAccount(
            id: AccountSeed.defaultBankID,
            name: "Bank",
            kind: .normal,
            openingBalance: .zero,
            currencyCode: VNDCurrency.code,
            createdAt: occurredAt
        )
        let food = TransactionCategory(
            id: UUID(),
            name: CategorySeed.defaultExpenseName,
            kind: .expense,
            symbolName: "fork.knife",
            colorName: "peach",
            createdAt: occurredAt
        )
        var draft = TransactionDraft(kind: .income, occurredAt: occurredAt)

        TransactionDefaults.apply(
            accountValue: "",
            categoryValue: "",
            accounts: [bank],
            categories: [food],
            to: &draft
        )

        #expect(draft.kind == .expense)
        #expect(draft.accountID == bank.id)
        #expect(draft.categoryID == food.id)
    }

    @Test("Stored valid preferences override the seeded defaults")
    func storedPreferencesOverrideSeedDefaults() {
        let bank = CashAccount(
            id: AccountSeed.defaultBankID,
            name: "Bank",
            kind: .normal,
            openingBalance: .zero,
            currencyCode: VNDCurrency.code,
            createdAt: occurredAt
        )
        let wallet = CashAccount(
            id: UUID(),
            name: "Wallet",
            kind: .normal,
            openingBalance: .zero,
            currencyCode: VNDCurrency.code,
            createdAt: occurredAt
        )
        let food = TransactionCategory(
            id: UUID(),
            name: CategorySeed.defaultExpenseName,
            kind: .expense,
            symbolName: "fork.knife",
            colorName: "peach",
            createdAt: occurredAt
        )
        let transport = TransactionCategory(
            id: UUID(),
            name: "Transport",
            kind: .expense,
            symbolName: "car.fill",
            colorName: "blue",
            createdAt: occurredAt
        )
        var draft = TransactionDraft(kind: .income, occurredAt: occurredAt)

        TransactionDefaults.apply(
            accountValue: wallet.id.uuidString,
            categoryValue: transport.id.uuidString,
            accounts: [bank, wallet],
            categories: [food, transport],
            to: &draft
        )

        #expect(draft.kind == .expense)
        #expect(draft.accountID == wallet.id)
        #expect(draft.categoryID == transport.id)
    }

    @Test("Stale account and income category preferences are not applied")
    func invalidPreferencesAreNotApplied() {
        let salary = TransactionCategory(
            id: UUID(),
            name: "Salary",
            kind: .income,
            symbolName: "briefcase.fill",
            colorName: "green",
            createdAt: occurredAt
        )
        var draft = TransactionDraft(kind: .income, occurredAt: occurredAt)

        TransactionDefaults.apply(
            accountValue: UUID().uuidString,
            categoryValue: salary.id.uuidString,
            accounts: [],
            categories: [salary],
            to: &draft
        )

        #expect(draft.kind == .expense)
        #expect(draft.accountID == nil)
        #expect(draft.categoryID == nil)
    }

    @Test("A missing income preference falls back on the seeded Salary")
    func missingIncomePreferenceUsesSeedDefault() {
        let salary = TransactionCategory(
            id: UUID(),
            name: CategorySeed.defaultIncomeName,
            kind: .income,
            symbolName: "briefcase.fill",
            colorName: "green",
            createdAt: occurredAt
        )
        let food = TransactionCategory(
            id: UUID(),
            name: CategorySeed.defaultExpenseName,
            kind: .expense,
            symbolName: "fork.knife",
            colorName: "peach",
            createdAt: occurredAt
        )

        #expect(
            TransactionDefaults.categoryID(
                for: .income,
                expenseValue: "",
                incomeValue: "",
                categories: [food, salary]
            ) == salary.id
        )
    }

    @Test("Each direction reads its own stored preference")
    func eachDirectionReadsItsOwnPreference() {
        let bonus = TransactionCategory(
            id: UUID(),
            name: "Bonus",
            kind: .income,
            symbolName: "gift.fill",
            colorName: "yellow",
            createdAt: occurredAt
        )
        let transport = TransactionCategory(
            id: UUID(),
            name: "Transport",
            kind: .expense,
            symbolName: "car.fill",
            colorName: "blue",
            createdAt: occurredAt
        )
        let categories = [transport, bonus]

        #expect(
            TransactionDefaults.categoryID(
                for: .expense,
                expenseValue: transport.id.uuidString,
                incomeValue: bonus.id.uuidString,
                categories: categories
            ) == transport.id
        )
        #expect(
            TransactionDefaults.categoryID(
                for: .income,
                expenseValue: transport.id.uuidString,
                incomeValue: bonus.id.uuidString,
                categories: categories
            ) == bonus.id
        )
    }

    /// A preference naming a category from the other direction is stale in the
    /// way that matters most: it would file an expense under Salary.
    @Test("A preference from the wrong direction is not applied")
    func crossDirectionPreferenceIsNotApplied() {
        let bonus = TransactionCategory(
            id: UUID(),
            name: "Bonus",
            kind: .income,
            symbolName: "gift.fill",
            colorName: "yellow",
            createdAt: occurredAt
        )

        #expect(
            TransactionDefaults.categoryID(
                for: .expense,
                expenseValue: bonus.id.uuidString,
                incomeValue: "",
                categories: [bonus]
            ) == nil
        )
    }

    @Test("A direction with no category at all has no default")
    func directionWithoutCategoriesHasNoDefault() {
        #expect(
            TransactionDefaults.categoryID(
                for: .income,
                expenseValue: "",
                incomeValue: "",
                categories: []
            ) == nil
        )
    }

    @Test("A complete draft becomes a transaction with a positive amount")
    func completeDraftValidates() throws {
        let draft = makeDraft(kind: .expense, amountText: "1.250.000", note: "  Lunch  ")

        let transaction = try draft.makeTransaction(id: UUID(), createdAt: occurredAt)

        #expect(transaction.kind == .expense)
        #expect(transaction.amount == 1_250_000)
        #expect(transaction.signedAmount == -1_250_000)
        #expect(transaction.note == "Lunch")
        #expect(transaction.accountID == accountID)
        #expect(transaction.categoryID == categoryID)
        #expect(transaction.currencyCode == VNDCurrency.code)
    }

    @Test("Income keeps the same positive amount and flips only the sign")
    func incomeSharesTheAmountConvention() throws {
        let draft = makeDraft(kind: .income, amountText: "5.000.000")

        let transaction = try draft.makeTransaction(id: UUID(), createdAt: occurredAt)

        #expect(transaction.amount == 5_000_000)
        #expect(transaction.signedAmount == 5_000_000)
    }

    @Test("A Trip expense preserves its workspace and jar override through editing")
    func tripMetadataRoundTripsThroughDraft() throws {
        let tripID = UUID()
        let jarID = UUID()
        var draft = makeDraft()
        draft.tripWorkspaceID = tripID
        draft.budgetJarOverrideID = jarID

        let transaction = try draft.makeTransaction(id: UUID(), createdAt: occurredAt)
        let editingDraft = TransactionDraft(transaction: transaction)

        #expect(transaction.tripWorkspaceID == tripID)
        #expect(transaction.budgetJarOverrideID == jarID)
        #expect(editingDraft.tripWorkspaceID == tripID)
        #expect(editingDraft.budgetJarOverrideID == jarID)

        let replacementTripID = UUID()
        let replacementJarID = UUID()
        var updatedDraft = editingDraft
        updatedDraft.tripWorkspaceID = replacementTripID
        updatedDraft.budgetJarOverrideID = replacementJarID
        try updatedDraft.apply(to: transaction)

        #expect(transaction.tripWorkspaceID == replacementTripID)
        #expect(transaction.budgetJarOverrideID == replacementJarID)
    }

    @Test("Income cannot join a Trip and an override cannot exist by itself")
    func invalidTripMetadataIsRejected() {
        var income = makeDraft(kind: .income)
        income.tripWorkspaceID = UUID()
        #expect(throws: TransactionFormError.tripRequiresExpense) {
            _ = try income.makeTransaction(id: UUID(), createdAt: occurredAt)
        }

        var overrideOnly = makeDraft()
        overrideOnly.budgetJarOverrideID = UUID()
        #expect(throws: TransactionFormError.jarOverrideRequiresTrip) {
            _ = try overrideOnly.makeTransaction(id: UUID(), createdAt: occurredAt)
        }
    }

    @Test("An unparsable amount is rejected")
    func unparsableAmountIsRejected() {
        let draft = makeDraft(amountText: "a lot")

        #expect(throws: TransactionFormError.invalidAmount) {
            try draft.makeTransaction(id: UUID(), createdAt: occurredAt)
        }
    }

    @Test("An empty amount is rejected")
    func emptyAmountIsRejected() {
        let draft = makeDraft(amountText: "")

        #expect(throws: TransactionFormError.invalidAmount) {
            try draft.makeTransaction(id: UUID(), createdAt: occurredAt)
        }
    }

    @Test("Zero and negative amounts are rejected")
    func nonPositiveAmountIsRejected() {
        #expect(throws: TransactionFormError.nonPositiveAmount) {
            try makeDraft(amountText: "0").makeTransaction(id: UUID(), createdAt: occurredAt)
        }
        #expect(throws: TransactionFormError.nonPositiveAmount) {
            try makeDraft(amountText: "-5.000").makeTransaction(id: UUID(), createdAt: occurredAt)
        }
    }

    @Test("A missing account is rejected")
    func missingAccountIsRejected() {
        var draft = makeDraft()
        draft.accountID = nil

        #expect(throws: TransactionFormError.missingAccount) {
            try draft.makeTransaction(id: UUID(), createdAt: occurredAt)
        }
    }

    @Test("A missing category is rejected")
    func missingCategoryIsRejected() {
        var draft = makeDraft()
        draft.categoryID = nil

        #expect(throws: TransactionFormError.missingCategory) {
            try draft.makeTransaction(id: UUID(), createdAt: occurredAt)
        }
    }

    @Test("A transaction round trips through a draft")
    func transactionRoundTripsThroughDraft() throws {
        let original = try makeDraft(kind: .income, amountText: "48.900.000", note: "Salary")
            .makeTransaction(id: UUID(), createdAt: occurredAt)

        let draft = TransactionDraft(transaction: original)
        let rebuilt = try draft.makeTransaction(id: UUID(), createdAt: occurredAt)

        #expect(rebuilt.kind == original.kind)
        #expect(rebuilt.amount == original.amount)
        #expect(rebuilt.occurredAt == original.occurredAt)
        #expect(rebuilt.note == original.note)
        #expect(rebuilt.accountID == original.accountID)
        #expect(rebuilt.categoryID == original.categoryID)
    }

    @Test("Applying a draft rewrites every editable field")
    func applyRewritesEveryField() throws {
        let transaction = try makeDraft().makeTransaction(id: UUID(), createdAt: occurredAt)
        let otherAccountID = UUID()
        let otherCategoryID = UUID()
        let laterDate = occurredAt.addingTimeInterval(86_400)

        var draft = TransactionDraft(transaction: transaction)
        draft.kind = .income
        draft.amountText = "900.000"
        draft.occurredAt = laterDate
        draft.note = "Refund"
        draft.accountID = otherAccountID
        draft.categoryID = otherCategoryID

        try draft.apply(to: transaction)

        #expect(transaction.kind == .income)
        #expect(transaction.amount == 900_000)
        #expect(transaction.occurredAt == laterDate)
        #expect(transaction.note == "Refund")
        #expect(transaction.accountID == otherAccountID)
        #expect(transaction.categoryID == otherCategoryID)
    }

    @Test("Invalid input never mutates the transaction it was applied to")
    func failedApplyLeavesTheModelAlone() throws {
        let transaction = try makeDraft().makeTransaction(id: UUID(), createdAt: occurredAt)

        var draft = TransactionDraft(transaction: transaction)
        draft.amountText = "nonsense"

        #expect(throws: TransactionFormError.invalidAmount) {
            try draft.apply(to: transaction)
        }
        #expect(transaction.amount == 200_000)
    }
}

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

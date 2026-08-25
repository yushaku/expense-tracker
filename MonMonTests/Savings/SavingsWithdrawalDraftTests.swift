import Foundation
import Testing

@testable import MonMon

@Suite("Savings withdrawal draft")
struct SavingsWithdrawalDraftTests {
    private let openedAt = Date(timeIntervalSince1970: 1_700_000_000)
    private let today = Date(timeIntervalSince1970: 1_710_000_000)

    private func makeDraft(
        principalText: String = "30.000.000",
        amountReceivedText: String = "30.100.000",
        withdrawnAt: Date? = nil,
        destinationAccountID: UUID? = UUID(),
        note: String = ""
    ) -> SavingsWithdrawalDraft {
        SavingsWithdrawalDraft(
            principalText: principalText,
            amountReceivedText: amountReceivedText,
            withdrawnAt: withdrawnAt ?? openedAt.addingTimeInterval(86_400),
            destinationAccountID: destinationAccountID,
            note: note
        )
    }

    @Test("A withdrawal validates its principal, proceeds, account, and note")
    func validWithdrawalValidates() throws {
        let accountID = UUID()
        let values = try makeDraft(destinationAccountID: accountID, note: "  early withdrawal  ")
            .validate(remainingPrincipal: 100_000_000, openedAt: openedAt, asOf: today)

        #expect(values.principal == 30_000_000)
        #expect(values.amountReceived == 30_100_000)
        #expect(values.destinationAccountID == accountID)
        #expect(values.note == "early withdrawal")
    }

    @Test("Receiving less than principal, including zero, is allowed")
    func lossIsAllowed() throws {
        let values = try makeDraft(amountReceivedText: "0")
            .validate(remainingPrincipal: 100_000_000, openedAt: openedAt, asOf: today)

        #expect(values.amountReceived == 0)
    }

    @Test("A withdrawal cannot exceed the remaining principal")
    func overWithdrawalIsRefused() {
        #expect(throws: SavingsWithdrawalFormError.exceedsRemainingPrincipal) {
            try makeDraft(principalText: "100.000.001")
                .validate(remainingPrincipal: 100_000_000, openedAt: openedAt, asOf: today)
        }
    }

    @Test("Principal must be a positive currency amount")
    func principalMustBePositive() {
        #expect(throws: SavingsWithdrawalFormError.invalidPrincipal) {
            try makeDraft(principalText: "abc")
                .validate(remainingPrincipal: 100_000_000, openedAt: openedAt, asOf: today)
        }
        #expect(throws: SavingsWithdrawalFormError.nonPositivePrincipal) {
            try makeDraft(principalText: "0")
                .validate(remainingPrincipal: 100_000_000, openedAt: openedAt, asOf: today)
        }
    }

    @Test("Amount received must be numeric and nonnegative")
    func amountReceivedMustBeNonnegative() {
        #expect(throws: SavingsWithdrawalFormError.invalidAmountReceived) {
            try makeDraft(amountReceivedText: "abc")
                .validate(remainingPrincipal: 100_000_000, openedAt: openedAt, asOf: today)
        }
        #expect(throws: SavingsWithdrawalFormError.negativeAmountReceived) {
            try makeDraft(amountReceivedText: "-1")
                .validate(remainingPrincipal: 100_000_000, openedAt: openedAt, asOf: today)
        }
    }

    @Test("Withdrawal date must be within the deposit lifetime through today")
    func dateMustBeInRange() {
        #expect(throws: SavingsWithdrawalFormError.beforeOpeningDate) {
            try makeDraft(withdrawnAt: openedAt.addingTimeInterval(-1))
                .validate(remainingPrincipal: 100_000_000, openedAt: openedAt, asOf: today)
        }
        #expect(throws: SavingsWithdrawalFormError.futureDate) {
            try makeDraft(withdrawnAt: today.addingTimeInterval(1))
                .validate(remainingPrincipal: 100_000_000, openedAt: openedAt, asOf: today)
        }
    }

    @Test("A destination account is required")
    func accountIsRequired() {
        #expect(throws: SavingsWithdrawalFormError.missingAccount) {
            try makeDraft(destinationAccountID: nil)
                .validate(remainingPrincipal: 100_000_000, openedAt: openedAt, asOf: today)
        }
    }
}

import Foundation
import Testing

@testable import MonMon

@Suite("Debt payment draft validation")
struct DebtPaymentDraftTests {
    private let createdAt = Date(timeIntervalSince1970: 1_700_000_000)
    private let debtID = UUID()
    private let accountID = UUID()

    private func makeDraft(
        amountText: String = "2.000.000",
        accountID: UUID? = nil,
        note: String = ""
    ) -> DebtPaymentDraft {
        DebtPaymentDraft(
            amountText: amountText,
            occurredAt: createdAt,
            accountID: accountID ?? self.accountID,
            note: note
        )
    }

    private func makePayment(
        _ draft: DebtPaymentDraft,
        direction: DebtDirection = .borrowed,
        outstanding: Decimal = 10_000_000,
        availableSourceBalance: Decimal? = nil
    ) throws -> DebtPayment {
        try draft.makePayment(
            id: UUID(),
            debtID: debtID,
            createdAt: createdAt,
            direction: direction,
            outstanding: outstanding,
            availableSourceBalance: availableSourceBalance
        )
    }

    // MARK: - The happy paths

    @Test("A complete draft becomes a payment with a positive amount")
    func draftBecomesAPayment() throws {
        let payment = try makePayment(makeDraft())

        #expect(payment.amount == 2_000_000)
        #expect(payment.debtID == debtID)
        #expect(payment.accountID == accountID)
        #expect(payment.currencyCode == VNDCurrency.code)
    }

    @Test("A payment reverses the direction of the debt it belongs to")
    func paymentsReverseTheirDebt() throws {
        let payment = try makePayment(makeDraft())

        #expect(payment.signedAmount(for: .borrowed) == -2_000_000)
        #expect(payment.signedAmount(for: .lent) == 2_000_000)
    }

    @Test("The note is trimmed before it is stored")
    func noteIsTrimmed() throws {
        let payment = try makePayment(makeDraft(note: "  first instalment  "))

        #expect(payment.note == "first instalment")
    }

    // MARK: - Amount

    @Test("An unreadable amount is rejected")
    func unreadableAmountIsRejected() {
        #expect(throws: DebtPaymentFormError.invalidAmount) {
            try makeDraft(amountText: "two million").validate(
                direction: .borrowed,
                outstanding: 10_000_000,
                availableSourceBalance: nil
            )
        }
    }

    @Test("Zero and negative amounts are rejected")
    func nonPositiveAmountsAreRejected() {
        for text in ["0", "-500"] {
            #expect(throws: DebtPaymentFormError.nonPositiveAmount) {
                try makeDraft(amountText: text).validate(
                    direction: .borrowed,
                    outstanding: 10_000_000,
                    availableSourceBalance: nil
                )
            }
        }
    }

    // MARK: - Account

    @Test("A payment with no chosen account is rejected")
    func missingAccountIsRejected() {
        var draft = makeDraft()
        draft.accountID = nil

        #expect(throws: DebtPaymentFormError.missingAccount) {
            try draft.validate(
                direction: .borrowed,
                outstanding: 10_000_000,
                availableSourceBalance: nil
            )
        }
    }

    @Test("A payment may name an account other than the one that opened the debt")
    func anotherAccountIsAllowed() throws {
        let other = UUID()
        let payment = try makePayment(makeDraft(accountID: other))

        #expect(payment.accountID == other)
    }

    // MARK: - The outstanding cap

    @Test("A payment larger than what is still outstanding is rejected")
    func overpaymentIsRejected() {
        #expect(throws: DebtPaymentFormError.exceedsOutstanding) {
            try makeDraft(amountText: "10.000.001").validate(
                direction: .borrowed,
                outstanding: 10_000_000,
                availableSourceBalance: nil
            )
        }
    }

    @Test("A payment for exactly what is outstanding is allowed")
    func settlingExactlyIsAllowed() throws {
        let payment = try makePayment(
            makeDraft(amountText: "10.000.000"),
            outstanding: 10_000_000
        )

        #expect(payment.amount == 10_000_000)
    }

    @Test("A payment against a settled debt is rejected")
    func payingASettledDebtIsRejected() {
        #expect(throws: DebtPaymentFormError.exceedsOutstanding) {
            try makeDraft(amountText: "1").validate(
                direction: .borrowed,
                outstanding: 0,
                availableSourceBalance: nil
            )
        }
    }

    // MARK: - The source balance guard

    @Test("Repaying a borrowed debt from an account that cannot cover it is rejected")
    func repayingIsCapped() {
        #expect(throws: DebtPaymentFormError.insufficientSourceBalance) {
            try makeDraft(amountText: "2.000.000").validate(
                direction: .borrowed,
                outstanding: 10_000_000,
                availableSourceBalance: 1_999_999
            )
        }
    }

    @Test("Repaying exactly the account balance is allowed")
    func repayingTheWholeBalanceIsAllowed() throws {
        let payment = try makePayment(
            makeDraft(amountText: "2.000.000"),
            availableSourceBalance: 2_000_000
        )

        #expect(payment.amount == 2_000_000)
    }

    @Test("Repaying a borrowed debt is allowed to overdraw a credit card")
    func repayingMayOverdrawACreditCard() throws {
        // `nil` is how a card allowed to go negative reaches the draft.
        let payment = try makePayment(
            makeDraft(amountText: "2.000.000"),
            availableSourceBalance: nil
        )

        #expect(payment.amount == 2_000_000)
    }

    @Test("Being repaid on a lent debt is never capped by the account balance")
    func beingRepaidIsNeverCapped() throws {
        let payment = try makePayment(
            makeDraft(amountText: "2.000.000"),
            direction: .lent,
            availableSourceBalance: 0
        )

        #expect(payment.amount == 2_000_000)
    }

    // MARK: - Editing

    @Test("Editing rewrites the payment in place")
    func editingRewritesInPlace() throws {
        let payment = try makePayment(makeDraft())
        let id = payment.id
        var draft = DebtPaymentDraft(payment: payment)
        draft.amountText = "3.000.000"

        try draft.apply(
            to: payment,
            direction: .borrowed,
            outstanding: 10_000_000,
            availableSourceBalance: nil
        )

        #expect(payment.id == id)
        #expect(payment.amount == 3_000_000)
        #expect(payment.debtID == debtID)
        #expect(payment.createdAt == createdAt)
    }

    @Test("Editing a payment adds its own amount back before the outstanding is checked")
    func editingAddsItsOwnAmountBackToOutstanding() throws {
        let payment = try makePayment(
            makeDraft(amountText: "10.000.000"),
            outstanding: 10_000_000
        )
        let draft = DebtPaymentDraft(payment: payment)

        // The debt now reads settled, because this very payment settled it.
        let outstanding = Decimal.zero + payment.amount

        #expect(throws: Never.self) {
            try draft.apply(
                to: payment,
                direction: .borrowed,
                outstanding: outstanding,
                availableSourceBalance: nil
            )
        }
    }

    @Test("Editing a payment adds its own amount back before the account balance is checked")
    func editingAddsItsOwnAmountBackToTheBalance() throws {
        let payment = try makePayment(
            makeDraft(amountText: "2.000.000"),
            availableSourceBalance: 2_000_000
        )
        let draft = DebtPaymentDraft(payment: payment)

        // The account reads zero because this payment emptied it. Removing the
        // payment's signed amount gives the true base back.
        let available = Decimal.zero - payment.signedAmount(for: .borrowed)

        #expect(available == 2_000_000)
        #expect(throws: Never.self) {
            try draft.apply(
                to: payment,
                direction: .borrowed,
                outstanding: 10_000_000,
                availableSourceBalance: available
            )
        }
    }

    @Test("A draft reloaded from a payment round trips unchanged")
    func draftRoundTrips() throws {
        let payment = try makePayment(makeDraft(amountText: "4.500.000", note: "March"))
        let reloaded = DebtPaymentDraft(payment: payment)
        let values = try reloaded.validate(
            direction: .borrowed,
            outstanding: 10_000_000,
            availableSourceBalance: nil
        )

        #expect(values.amount == 4_500_000)
        #expect(values.note == "March")
        #expect(values.accountID == accountID)
        #expect(values.occurredAt == createdAt)
    }
}

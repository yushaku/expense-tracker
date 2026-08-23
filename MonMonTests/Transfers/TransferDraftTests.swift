import Foundation
import Testing

@testable import MonMon

@Suite("Transfer draft validation")
struct TransferDraftTests {
    private let occurredAt = Date(timeIntervalSince1970: 1_700_000_000)
    private let sourceAccountID = UUID()
    private let destinationAccountID = UUID()

    private func makeDraft(
        amountText: String = "2.000.000",
        note: String = "",
        sourceAccountID: UUID? = nil,
        destinationAccountID: UUID? = nil
    ) -> TransferDraft {
        TransferDraft(
            amountText: amountText,
            occurredAt: occurredAt,
            note: note,
            sourceAccountID: sourceAccountID ?? self.sourceAccountID,
            destinationAccountID: destinationAccountID ?? self.destinationAccountID
        )
    }

    @Test("A complete draft becomes a transfer with a positive amount")
    func completeDraftValidates() throws {
        let draft = makeDraft(amountText: "2.500.000", note: "  Top up the wallet  ")

        let transfer = try draft.makeTransfer(
            id: UUID(),
            createdAt: occurredAt,
            availableSourceBalance: nil
        )

        #expect(transfer.amount == 2_500_000)
        #expect(transfer.note == "Top up the wallet")
        #expect(transfer.sourceAccountID == sourceAccountID)
        #expect(transfer.destinationAccountID == destinationAccountID)
        #expect(transfer.currencyCode == VNDCurrency.code)
    }

    @Test("The direction lives in the pair of accounts, not in a sign")
    func directionComesFromTheAccounts() throws {
        let transfer = try makeDraft().makeTransfer(
            id: UUID(),
            createdAt: occurredAt,
            availableSourceBalance: nil
        )

        #expect(transfer.signedAmount(for: sourceAccountID) == -2_000_000)
        #expect(transfer.signedAmount(for: destinationAccountID) == 2_000_000)
        #expect(transfer.signedAmount(for: UUID()) == 0)
    }

    @Test("An unreadable amount is rejected")
    func unreadableAmountFails() {
        #expect(throws: TransferFormError.invalidAmount) {
            try makeDraft(amountText: "two million").validate(availableSourceBalance: nil)
        }
    }

    @Test("Zero and negative amounts are rejected")
    func nonPositiveAmountFails() {
        for amountText in ["0", "-1.000"] {
            #expect(throws: TransferFormError.nonPositiveAmount) {
                try makeDraft(amountText: amountText).validate(availableSourceBalance: nil)
            }
        }
    }

    @Test("Both ends are required")
    func missingAccountsFail() {
        #expect(throws: TransferFormError.missingSourceAccount) {
            try TransferDraft(
                amountText: "1.000.000",
                occurredAt: occurredAt,
                destinationAccountID: destinationAccountID
            )
            .validate(availableSourceBalance: nil)
        }

        #expect(throws: TransferFormError.missingDestinationAccount) {
            try TransferDraft(
                amountText: "1.000.000",
                occurredAt: occurredAt,
                sourceAccountID: sourceAccountID
            )
            .validate(availableSourceBalance: nil)
        }
    }

    @Test("An account cannot transfer to itself")
    func sameAccountFails() {
        #expect(throws: TransferFormError.sameAccount) {
            try makeDraft(destinationAccountID: sourceAccountID)
                .validate(availableSourceBalance: nil)
        }
    }

    @Test("More than the source account holds is rejected")
    func overdraftFails() {
        #expect(throws: TransferFormError.insufficientSourceBalance) {
            try makeDraft(amountText: "2.000.000")
                .validate(availableSourceBalance: 1_999_999)
        }
    }

    @Test("Exactly the source balance is allowed")
    func spendingTheWholeBalanceIsAllowed() throws {
        let values = try makeDraft(amountText: "2.000.000")
            .validate(availableSourceBalance: 2_000_000)

        #expect(values.amount == 2_000_000)
    }

    @Test("Editing rewrites the transfer in place")
    func applyUpdatesTheTransfer() throws {
        let transfer = try makeDraft().makeTransfer(
            id: UUID(),
            createdAt: occurredAt,
            availableSourceBalance: nil
        )
        var draft = TransferDraft(transfer: transfer)
        draft.amountText = "750.000"
        draft.note = "Corrected"
        draft.swapEnds()

        try draft.apply(to: transfer, availableSourceBalance: nil)

        #expect(transfer.amount == 750_000)
        #expect(transfer.note == "Corrected")
        #expect(transfer.sourceAccountID == destinationAccountID)
        #expect(transfer.destinationAccountID == sourceAccountID)
    }

    @Test("A draft reloaded from a transfer round trips unchanged")
    func draftFromTransferRoundTrips() throws {
        let transfer = try makeDraft(amountText: "1.234.000", note: "Rent pot")
            .makeTransfer(id: UUID(), createdAt: occurredAt, availableSourceBalance: nil)

        let draft = TransferDraft(transfer: transfer)

        #expect(draft.amountText == VNDCurrency.formatPlain(1_234_000))
        #expect(draft.note == "Rent pot")
        #expect(draft.sourceAccountID == sourceAccountID)
        #expect(draft.destinationAccountID == destinationAccountID)
    }
}

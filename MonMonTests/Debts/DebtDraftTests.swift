import Foundation
import Testing

@testable import MonMon

@Suite("Debt draft validation")
struct DebtDraftTests {
    private let createdAt = Date(timeIntervalSince1970: 1_700_000_000)
    private let accountID = UUID()

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        let components = DateComponents(year: year, month: month, day: day)
        return DebtInterest.calendar.date(from: components) ?? .distantPast
    }

    private func makeDraft(
        counterparty: String = "Anh Minh",
        direction: DebtDirection = .borrowed,
        principalText: String = "10.000.000",
        rateText: String = "",
        openedAt: Date? = nil,
        hasDueDate: Bool = false,
        dueDate: Date? = nil,
        accountID: UUID? = nil,
        note: String = ""
    ) -> DebtDraft {
        DebtDraft(
            counterparty: counterparty,
            direction: direction,
            principalText: principalText,
            rateText: rateText,
            openedAt: openedAt ?? createdAt,
            hasDueDate: hasDueDate,
            dueDate: dueDate,
            accountID: accountID ?? self.accountID,
            note: note
        )
    }

    // MARK: - The happy paths

    @Test("A complete borrowed draft becomes a debt with a positive principal")
    func borrowedDraftBecomesADebt() throws {
        let draft = makeDraft(direction: .borrowed)
        let debt = try draft.makeDebt(
            id: UUID(),
            createdAt: createdAt,
            availableSourceBalance: nil
        )

        #expect(debt.direction == .borrowed)
        #expect(debt.principal == 10_000_000)
        #expect(debt.counterparty == "Anh Minh")
        #expect(debt.currencyCode == VNDCurrency.code)
    }

    @Test("The direction lives in the debt, not in the sign of the principal")
    func directionIsNotASign() throws {
        let lent = try makeDraft(direction: .lent)
            .makeDebt(id: UUID(), createdAt: createdAt, availableSourceBalance: nil)

        #expect(lent.direction == .lent)
        #expect(lent.principal == 10_000_000)
        #expect(lent.signedPrincipal == -10_000_000)
    }

    @Test("Borrowing lands the principal in the chosen account")
    func borrowingLands() throws {
        let debt = try makeDraft(direction: .borrowed)
            .makeDebt(id: UUID(), createdAt: createdAt, availableSourceBalance: nil)

        #expect(debt.signedPrincipal(for: accountID) == 10_000_000)
    }

    @Test("Lending takes the principal out of the chosen account")
    func lendingLeaves() throws {
        let debt = try makeDraft(direction: .lent)
            .makeDebt(id: UUID(), createdAt: createdAt, availableSourceBalance: nil)

        #expect(debt.signedPrincipal(for: accountID) == -10_000_000)
    }

    @Test("A debt may name no account at all")
    func anUnlinkedDebtIsAllowed() throws {
        var draft = makeDraft()
        draft.accountID = nil
        let debt = try draft.makeDebt(
            id: UUID(),
            createdAt: createdAt,
            availableSourceBalance: nil
        )

        #expect(debt.accountID == nil)
        #expect(debt.signedPrincipal(for: accountID) == 0)
    }

    @Test("The counterparty and the note are trimmed before they are stored")
    func textIsTrimmed() throws {
        let debt = try makeDraft(counterparty: "  Anh Minh  ", note: "  a loan  ")
            .makeDebt(id: UUID(), createdAt: createdAt, availableSourceBalance: nil)

        #expect(debt.counterparty == "Anh Minh")
        #expect(debt.note == "a loan")
    }

    // MARK: - Counterparty

    @Test("An empty counterparty is rejected")
    func emptyCounterpartyIsRejected() {
        #expect(throws: DebtFormError.emptyCounterparty) {
            try makeDraft(counterparty: "").validate(availableSourceBalance: nil)
        }
    }

    @Test("A counterparty of only whitespace is rejected")
    func whitespaceCounterpartyIsRejected() {
        #expect(throws: DebtFormError.emptyCounterparty) {
            try makeDraft(counterparty: "   ").validate(availableSourceBalance: nil)
        }
    }

    // MARK: - Principal

    @Test("An unreadable principal is rejected")
    func unreadablePrincipalIsRejected() {
        #expect(throws: DebtFormError.invalidPrincipal) {
            try makeDraft(principalText: "ten million").validate(availableSourceBalance: nil)
        }
    }

    @Test("Zero and negative principals are rejected")
    func nonPositivePrincipalsAreRejected() {
        #expect(throws: DebtFormError.nonPositivePrincipal) {
            try makeDraft(principalText: "0").validate(availableSourceBalance: nil)
        }
        #expect(throws: DebtFormError.nonPositivePrincipal) {
            try makeDraft(principalText: "-500").validate(availableSourceBalance: nil)
        }
    }

    // MARK: - Rate

    @Test("A blank rate is read as no interest, because most private loans charge none")
    func blankRateMeansZero() throws {
        let values = try makeDraft(rateText: "").validate(availableSourceBalance: nil)

        #expect(values.annualInterestRate == 0)
    }

    @Test("A rate typed with a comma and one typed with a dot mean the same")
    func rateAcceptsBothSeparators() throws {
        let comma = try makeDraft(rateText: "5,6").validate(availableSourceBalance: nil)
        let dot = try makeDraft(rateText: "5.6").validate(availableSourceBalance: nil)

        #expect(comma.annualInterestRate == dot.annualInterestRate)
        #expect(comma.annualInterestRate == Decimal(string: "5.6"))
    }

    @Test("A rate that was typed and cannot be read is rejected")
    func unreadableRateIsRejected() {
        #expect(throws: DebtFormError.invalidRate) {
            try makeDraft(rateText: "twelve").validate(availableSourceBalance: nil)
        }
    }

    @Test("A rate outside nought to a hundred is rejected")
    func rateOutOfRangeIsRejected() {
        #expect(throws: DebtFormError.rateOutOfRange) {
            try makeDraft(rateText: "101").validate(availableSourceBalance: nil)
        }
        #expect(throws: DebtFormError.rateOutOfRange) {
            try makeDraft(rateText: "-1").validate(availableSourceBalance: nil)
        }
    }

    // MARK: - Due date

    @Test("A due date before the opening date is rejected")
    func backwardsDueDateIsRejected() {
        #expect(throws: DebtFormError.dueDateBeforeOpening) {
            try makeDraft(
                openedAt: date(2026, 6, 1),
                hasDueDate: true,
                dueDate: date(2026, 5, 1)
            )
            .validate(availableSourceBalance: nil)
        }
    }

    @Test("A due date on the opening date is allowed")
    func sameDayDueDateIsAllowed() throws {
        let values = try makeDraft(
            openedAt: date(2026, 6, 1),
            hasDueDate: true,
            dueDate: date(2026, 6, 1)
        )
        .validate(availableSourceBalance: nil)

        #expect(values.dueDate == date(2026, 6, 1))
    }

    @Test("Turning the due date off clears it from the debt")
    func dueDateToggleClears() throws {
        let values = try makeDraft(
            openedAt: date(2026, 6, 1),
            hasDueDate: false,
            dueDate: date(2027, 6, 1)
        )
        .validate(availableSourceBalance: nil)

        #expect(values.dueDate == nil)
    }

    @Test("Turning the due date on writes the date the owner picked")
    func dueDateToggleWrites() throws {
        let values = try makeDraft(
            openedAt: date(2026, 6, 1),
            hasDueDate: true,
            dueDate: date(2027, 6, 1)
        )
        .validate(availableSourceBalance: nil)

        #expect(values.dueDate == date(2027, 6, 1))
    }

    // MARK: - The source balance guard

    @Test("Lending more than the account can hand over is rejected")
    func lendingIsCapped() {
        #expect(throws: DebtFormError.insufficientSourceBalance) {
            try makeDraft(direction: .lent, principalText: "10.000.000")
                .validate(availableSourceBalance: 9_999_999)
        }
    }

    @Test("Lending exactly the account balance is allowed")
    func lendingTheWholeBalanceIsAllowed() throws {
        let values = try makeDraft(direction: .lent, principalText: "10.000.000")
            .validate(availableSourceBalance: 10_000_000)

        #expect(values.principal == 10_000_000)
    }

    @Test("Borrowing is never capped by the account balance")
    func borrowingIsNeverCapped() throws {
        // Borrowing 500m into a wallet holding 1m is the single most common
        // thing this module is for.
        let values = try makeDraft(direction: .borrowed, principalText: "500.000.000")
            .validate(availableSourceBalance: 1_000_000)

        #expect(values.principal == 500_000_000)
    }

    @Test("An account allowed to go negative is never capped")
    func creditCardsAreUncapped() throws {
        let values = try makeDraft(direction: .lent, principalText: "10.000.000")
            .validate(availableSourceBalance: nil)

        #expect(values.principal == 10_000_000)
    }

    // MARK: - Editing

    @Test("Editing rewrites the debt in place")
    func editingRewritesInPlace() throws {
        let debt = try makeDraft().makeDebt(
            id: UUID(),
            createdAt: createdAt,
            availableSourceBalance: nil
        )
        let id = debt.id
        var draft = DebtDraft(debt: debt)
        draft.counterparty = "Chị Lan"
        draft.principalText = "12.000.000"

        try draft.apply(to: debt, availableSourceBalance: nil, alreadyPaid: 0)

        #expect(debt.id == id)
        #expect(debt.counterparty == "Chị Lan")
        #expect(debt.principal == 12_000_000)
        #expect(debt.createdAt == createdAt)
        #expect(debt.currencyCode == VNDCurrency.code)
    }

    @Test("The principal may not be edited below what has already been paid")
    func principalCannotDropBelowPaid() throws {
        let debt = try makeDraft(principalText: "10.000.000").makeDebt(
            id: UUID(),
            createdAt: createdAt,
            availableSourceBalance: nil
        )
        var draft = DebtDraft(debt: debt)
        draft.principalText = "3.000.000"

        #expect(throws: DebtFormError.principalBelowPaid) {
            try draft.apply(to: debt, availableSourceBalance: nil, alreadyPaid: 5_000_000)
        }
    }

    @Test("The principal may be edited down to exactly what has been paid, settling it")
    func principalMayMeetWhatIsPaid() throws {
        let debt = try makeDraft(principalText: "10.000.000").makeDebt(
            id: UUID(),
            createdAt: createdAt,
            availableSourceBalance: nil
        )
        var draft = DebtDraft(debt: debt)
        draft.principalText = "5.000.000"

        try draft.apply(to: debt, availableSourceBalance: nil, alreadyPaid: 5_000_000)

        #expect(debt.principal == 5_000_000)
    }

    @Test("Editing a lent debt adds its own principal back before the balance is checked")
    func editingALentDebtAddsItsOwnPrincipalBack() throws {
        let debt = try makeDraft(direction: .lent, principalText: "10.000.000").makeDebt(
            id: UUID(),
            createdAt: createdAt,
            availableSourceBalance: 10_000_000
        )
        let draft = DebtDraft(debt: debt)

        // The account now reads zero, because this very debt emptied it. The
        // editor removes the debt's signed principal — for a lent debt that is
        // `0 − (−10.000.000)`, so the unchanged amount re-saves cleanly.
        let available = Decimal.zero - debt.signedPrincipal

        #expect(available == 10_000_000)
        #expect(throws: Never.self) {
            try draft.apply(
                to: debt,
                availableSourceBalance: available,
                alreadyPaid: 0
            )
        }
    }

    @Test("Flipping a debt from borrowed to lent checks the balance it would really leave")
    func flippingToLentUsesTheSignedBase() throws {
        let debt = try makeDraft(direction: .borrowed, principalText: "10.000.000").makeDebt(
            id: UUID(),
            createdAt: createdAt,
            availableSourceBalance: nil
        )
        var draft = DebtDraft(debt: debt)
        draft.direction = .lent

        // The account reads 10.000.000 only because this debt put it there.
        // Removing the signed principal gives the true base of zero; adding the
        // amount back instead would say 20.000.000 and wave the loan through.
        let available = Decimal(10_000_000) - debt.signedPrincipal

        #expect(available == 0)
        #expect(throws: DebtFormError.insufficientSourceBalance) {
            try draft.apply(to: debt, availableSourceBalance: available, alreadyPaid: 0)
        }
    }

    @Test("Flipping a debt from lent to borrowed is never capped")
    func flippingToBorrowedIsNeverCapped() throws {
        let debt = try makeDraft(direction: .lent, principalText: "10.000.000").makeDebt(
            id: UUID(),
            createdAt: createdAt,
            availableSourceBalance: 10_000_000
        )
        var draft = DebtDraft(debt: debt)
        draft.direction = .borrowed

        let available = Decimal.zero - debt.signedPrincipal

        #expect(throws: Never.self) {
            try draft.apply(to: debt, availableSourceBalance: available, alreadyPaid: 0)
        }
        #expect(debt.direction == .borrowed)
        #expect(debt.signedPrincipal == 10_000_000)
    }

    @Test("A draft reloaded from a debt round trips unchanged")
    func draftRoundTrips() throws {
        let debt = try makeDraft(
            counterparty: "Techcombank",
            direction: .borrowed,
            principalText: "250.000.000",
            rateText: "8,5",
            openedAt: date(2026, 1, 1),
            hasDueDate: true,
            dueDate: date(2027, 1, 1),
            note: "car"
        )
        .makeDebt(id: UUID(), createdAt: createdAt, availableSourceBalance: nil)

        let reloaded = DebtDraft(debt: debt)
        let values = try reloaded.validate(availableSourceBalance: nil)

        #expect(values.counterparty == "Techcombank")
        #expect(values.principal == 250_000_000)
        #expect(values.annualInterestRate == Decimal(string: "8.5"))
        #expect(values.dueDate == date(2027, 1, 1))
        #expect(values.note == "car")
        #expect(reloaded.hasDueDate)
    }

    @Test("A draft reloaded from an interest-free debt leaves the rate field blank")
    func interestFreeDebtsReloadBlank() throws {
        let debt = try makeDraft(rateText: "").makeDebt(
            id: UUID(),
            createdAt: createdAt,
            availableSourceBalance: nil
        )

        #expect(DebtDraft(debt: debt).rateText.isEmpty)
    }
}

import Foundation
import Testing

@testable import MonMon

@Suite("Debt interest projection")
struct DebtInterestTests {
    private let createdAt = Date(timeIntervalSince1970: 1_700_000_000)

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        let components = DateComponents(year: year, month: month, day: day)
        return DebtInterest.calendar.date(from: components) ?? .distantPast
    }

    private func makeDebt(
        principal: Decimal = 10_000_000,
        rate: Decimal = 0,
        openedAt: Date,
        dueDate: Date? = nil
    ) -> Debt {
        Debt(
            id: UUID(),
            counterparty: "Anh Minh",
            direction: .borrowed,
            principal: principal,
            annualInterestRate: rate,
            openedAt: openedAt,
            dueDate: dueDate,
            accountID: nil,
            note: "",
            currencyCode: VNDCurrency.code,
            createdAt: createdAt
        )
    }

    @Test("A debt charging no rate projects no interest")
    func noRateProjectsNothing() {
        let debt = makeDebt(openedAt: date(2026, 1, 1), dueDate: date(2027, 1, 1))

        #expect(debt.projectedInterest(asOf: date(2026, 6, 1)) == 0)
        #expect(debt.totalDue(asOf: date(2026, 6, 1)) == 10_000_000)
    }

    @Test("A whole year at ten percent projects a tenth of the principal")
    func wholeYearAtTenPercent() {
        let interest = DebtInterest.projected(
            principal: 10_000_000,
            annualRatePercent: 10,
            from: date(2026, 1, 1),
            to: date(2027, 1, 1)
        )

        // 365 days of a 365-day year, so the full annual rate.
        #expect(interest == 1_000_000)
    }

    @Test("Interest is projected to the due date when the debt has one")
    func projectsToTheDueDate() {
        let debt = makeDebt(rate: 10, openedAt: date(2026, 1, 1), dueDate: date(2027, 1, 1))

        #expect(debt.projectedInterest(asOf: date(2026, 3, 1)) == 1_000_000)
        #expect(debt.totalDue(asOf: date(2026, 3, 1)) == 11_000_000)
    }

    @Test("Interest is projected to the day asked about when there is no due date")
    func projectsToTheDayAskedAbout() {
        let debt = makeDebt(rate: 10, openedAt: date(2026, 1, 1))

        #expect(debt.projectedInterest(asOf: date(2027, 1, 1)) == 1_000_000)
        #expect(debt.projectedInterest(asOf: date(2026, 1, 1)) == 0)
    }

    @Test("A due date already passed stops the projection at the due date")
    func aPassedDueDateStopsTheProjection() {
        let debt = makeDebt(rate: 10, openedAt: date(2026, 1, 1), dueDate: date(2027, 1, 1))

        // Two years after opening, but the agreed date caps what is projected.
        #expect(debt.projectedInterest(asOf: date(2028, 1, 1)) == 1_000_000)
    }

    @Test("Interest is projected on the original principal, not on what is left")
    func accruesOnTheOriginalPrincipal() {
        let debt = makeDebt(rate: 10, openedAt: date(2026, 1, 1), dueDate: date(2027, 1, 1))
        let payments = [
            DebtPayment(
                id: UUID(),
                debtID: debt.id,
                amount: 9_000_000,
                occurredAt: date(2026, 2, 1),
                accountID: UUID(),
                note: "",
                currencyCode: VNDCurrency.code,
                createdAt: createdAt
            )
        ]

        #expect(DebtSummary.outstanding(for: debt, payments: payments) == 1_000_000)
        #expect(debt.projectedInterest(asOf: date(2026, 6, 1)) == 1_000_000)
    }

    @Test("Interest is rounded to the đồng")
    func roundsToTheDong() {
        let interest = DebtInterest.projected(
            principal: 1_000_000,
            annualRatePercent: 7,
            from: date(2026, 1, 1),
            to: date(2026, 2, 1)
        )

        // 1.000.000 × 7% × 31/365 = 5945,2054…
        #expect(interest == 5_945)
    }

    @Test("A negative span projects nothing rather than a credit")
    func aBackwardsSpanProjectsNothing() {
        let interest = DebtInterest.projected(
            principal: 10_000_000,
            annualRatePercent: 10,
            from: date(2027, 1, 1),
            to: date(2026, 1, 1)
        )

        #expect(interest == 0)
    }

    @Test("A debt is past due only once the agreed date has gone by")
    func pastDueFollowsTheDate() {
        let dueDate = date(2026, 6, 1)

        #expect(DebtInterest.isPastDue(dueDate: dueDate, asOf: date(2026, 5, 31)) == false)
        #expect(DebtInterest.isPastDue(dueDate: dueDate, asOf: dueDate) == false)
        #expect(DebtInterest.isPastDue(dueDate: dueDate, asOf: date(2026, 6, 2)))
    }

    @Test("A debt that agreed no date is never past due")
    func noDueDateIsNeverPastDue() {
        #expect(DebtInterest.isPastDue(dueDate: nil, asOf: date(2030, 1, 1)) == false)
        #expect(DebtInterest.daysUntilDue(dueDate: nil, asOf: date(2030, 1, 1)) == nil)
    }

    @Test("Days until due count down and then go negative")
    func daysUntilDueCountDown() {
        let dueDate = date(2026, 6, 1)

        #expect(DebtInterest.daysUntilDue(dueDate: dueDate, asOf: date(2026, 5, 30)) == 2)
        #expect(DebtInterest.daysUntilDue(dueDate: dueDate, asOf: dueDate) == 0)
        #expect(DebtInterest.daysUntilDue(dueDate: dueDate, asOf: date(2026, 6, 4)) == -3)
    }
}

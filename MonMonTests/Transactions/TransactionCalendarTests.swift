import Foundation
import Testing

@testable import MonMon

@Suite("Transaction calendar")
struct TransactionCalendarTests {
    private let calendar = TransactionPeriod.calendar
    private let createdAt = Date(timeIntervalSince1970: 1_700_000_000)
    private let accountID = UUID()

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        let components = DateComponents(year: year, month: month, day: day)
        return TransactionPeriod.calendar.date(from: components) ?? .distantPast
    }

    private func makeTransaction(
        kind: TransactionKind,
        amount: Decimal,
        occurredAt: Date
    ) -> MoneyTransaction {
        MoneyTransaction(
            id: UUID(),
            kind: kind,
            amount: amount,
            occurredAt: occurredAt,
            note: "",
            accountID: accountID,
            categoryID: nil,
            sourceRuleID: nil,
            currencyCode: VNDCurrency.code,
            createdAt: createdAt
        )
    }

    private func day(_ weeks: [TransactionCalendarWeek], on date: Date) -> TransactionCalendarDay? {
        weeks.flatMap(\.days).first { calendar.isDate($0.date, inSameDayAs: date) }
    }

    @Test("Every row is a whole week starting on the calendar's first weekday")
    func rowsAreWholeWeeks() {
        let weeks = TransactionCalendar.weeks(of: date(2024, 3, 15), transactions: [])

        #expect(!weeks.isEmpty)

        for week in weeks {
            #expect(week.days.count == 7)
            #expect(calendar.component(.weekday, from: week.days[0].date) == calendar.firstWeekday)
        }
    }

    @Test("The grid covers the whole month and marks the days either side")
    func gridCoversTheMonth() {
        let weeks = TransactionCalendar.weeks(of: date(2024, 3, 15), transactions: [])
        let days = weeks.flatMap(\.days)
        let inMonth = days.filter(\.isInMonth)

        #expect(inMonth.count == 31)
        #expect(calendar.isDate(inMonth.first?.date ?? .distantPast, inSameDayAs: date(2024, 3, 1)))
        #expect(calendar.isDate(inMonth.last?.date ?? .distantPast, inSameDayAs: date(2024, 3, 31)))
        #expect(days.count.isMultiple(of: 7))
        #expect(day(weeks, on: date(2024, 2, 29))?.isInMonth == false)
    }

    @Test("A day carries what it took in, what it paid out, and how many entries")
    func dayTotalsSplitByDirection() {
        let transactions = [
            makeTransaction(kind: .income, amount: 5_000_000, occurredAt: date(2024, 3, 10)),
            makeTransaction(kind: .expense, amount: 200_000, occurredAt: date(2024, 3, 10)),
            makeTransaction(kind: .expense, amount: 300_000, occurredAt: date(2024, 3, 10)),
            makeTransaction(kind: .expense, amount: 900_000, occurredAt: date(2024, 3, 11)),
        ]

        let weeks = TransactionCalendar.weeks(of: date(2024, 3, 1), transactions: transactions)
        let tenth = day(weeks, on: date(2024, 3, 10))

        #expect(tenth?.income == 5_000_000)
        #expect(tenth?.expense == 500_000)
        #expect(tenth?.net == 4_500_000)
        #expect(tenth?.count == 3)
        #expect(tenth?.isEmpty == false)
        #expect(day(weeks, on: date(2024, 3, 11))?.expense == 900_000)
    }

    @Test("A day with nothing on it totals to zero")
    func untouchedDaysAreEmpty() {
        let transactions = [
            makeTransaction(kind: .expense, amount: 200_000, occurredAt: date(2024, 3, 10))
        ]

        let weeks = TransactionCalendar.weeks(of: date(2024, 3, 1), transactions: transactions)
        let ninth = day(weeks, on: date(2024, 3, 9))

        #expect(ninth?.income == 0)
        #expect(ninth?.expense == 0)
        #expect(ninth?.count == 0)
        #expect(ninth?.isEmpty == true)
    }

    @Test("Time of day does not move a transaction off its day")
    func transactionsLandOnTheirCalendarDay() {
        let lateEvening = calendar.date(
            bySettingHour: 23,
            minute: 45,
            second: 0,
            of: date(2024, 3, 10)
        )
        let transactions = [
            makeTransaction(kind: .expense, amount: 200_000, occurredAt: lateEvening ?? .now)
        ]

        let weeks = TransactionCalendar.weeks(of: date(2024, 3, 1), transactions: transactions)

        #expect(day(weeks, on: date(2024, 3, 10))?.expense == 200_000)
        #expect(day(weeks, on: date(2024, 3, 11))?.isEmpty == true)
    }

    @Test("The month total counts the month's own days, not the ones spilling in")
    func monthTotalsIgnoreSpillDays() {
        let transactions = [
            makeTransaction(kind: .income, amount: 5_000_000, occurredAt: date(2024, 3, 10)),
            makeTransaction(kind: .expense, amount: 200_000, occurredAt: date(2024, 3, 11)),
            makeTransaction(kind: .expense, amount: 700_000, occurredAt: date(2024, 2, 29)),
            makeTransaction(kind: .income, amount: 400_000, occurredAt: date(2024, 4, 1)),
        ]

        let weeks = TransactionCalendar.weeks(of: date(2024, 3, 1), transactions: transactions)
        let totals = TransactionCalendar.monthTotals(of: weeks)

        #expect(totals.income == 5_000_000)
        #expect(totals.expense == 200_000)
    }

    @Test("A spill day still shows what it recorded")
    func spillDaysKeepTheirTotals() {
        let transactions = [
            makeTransaction(kind: .expense, amount: 700_000, occurredAt: date(2024, 2, 29))
        ]

        let weeks = TransactionCalendar.weeks(of: date(2024, 3, 1), transactions: transactions)
        let leapDay = day(weeks, on: date(2024, 2, 29))

        #expect(leapDay?.isInMonth == false)
        #expect(leapDay?.expense == 700_000)
    }

    @Test("A month picked by any of its days gives the same grid")
    func anyDayOfTheMonthGivesTheSameGrid() {
        let first = TransactionCalendar.weeks(of: date(2024, 3, 1), transactions: [])
        let middle = TransactionCalendar.weeks(of: date(2024, 3, 17), transactions: [])

        #expect(first == middle)
    }
}

import Foundation

enum AssetSummary {
    static func totalPrincipal(of deposits: [SavingsDeposit]) -> Decimal {
        deposits.reduce(Decimal.zero) { total, deposit in
            total + deposit.principal
        }
    }

    static func totalProjectedInterest(of deposits: [SavingsDeposit]) -> Decimal {
        deposits.reduce(Decimal.zero) { total, deposit in
            total + deposit.projectedInterest
        }
    }

    static func totalMaturityValue(of deposits: [SavingsDeposit]) -> Decimal {
        totalPrincipal(of: deposits) + totalProjectedInterest(of: deposits)
    }

    /// Spendable cash, plus deposited principal, plus what the fund holdings are
    /// worth today, plus what is still owed to the owner, minus what the owner
    /// still owes. Money moved from an account into a deposit or a holding is
    /// already removed from the spendable side, so it is counted once; a holding
    /// contributes its market value, so an unrealized gain shows up as growth.
    /// Recorded income and expense reach this figure through the spendable side,
    /// so an expense lowers net worth by exactly its amount. An internal
    /// transfer leaves it untouched: it only moves money between two accounts
    /// that both already count here.
    ///
    /// Debts leave it untouched too, and for a subtler reason. Borrowing raises
    /// the spendable side and raises what is owed by the same amount; lending
    /// lowers the spendable side and raises what is owed to the owner by the
    /// same amount; a payment moves both back together. Only recording a debt
    /// that names no account moves this figure, and that is correct: stating a
    /// previously untracked obligation makes the owner poorer on paper.
    ///
    /// Selling a position leaves this figure exactly where it was at the moment
    /// of the sale, and that is the point of it. The lot keeps its original cost
    /// subtracted from the spendable side, the proceeds are added back there,
    /// and the market value drops by the units that went. At today's price those
    /// three cancel; the difference only shows once the price moves again, on
    /// whatever is still held. What was made is not lost, it has moved from an
    /// unrealized gain to cash the owner is holding.
    ///
    /// Money lent out counts at what is outstanding while a deposit counts at
    /// its principal. That is not an inconsistency: a deposit's principal sits
    /// untouched until maturity, whereas the repaid part of a loan has already
    /// landed back in cash and would otherwise be counted twice. Projected
    /// interest is left out of both.
    static func netWorth(
        accounts: [CashAccount],
        deposits: [SavingsDeposit],
        holdings: [FundHolding],
        instruments: [FundInstrument],
        transactions: [MoneyTransaction],
        transfers: [AccountTransfer],
        debts: [Debt],
        payments: [DebtPayment],
        sales: [FundSale]
    ) -> Decimal {
        CashBalanceSummary.totalAvailable(
            of: accounts,
            deposits: deposits,
            holdings: holdings,
            transactions: transactions,
            transfers: transfers,
            debts: debts,
            payments: payments,
            sales: sales
        )
            + totalPrincipal(of: deposits)
            + FundSummary.totalMarketValue(
                of: holdings,
                instruments: instruments,
                sales: sales
            )
            + DebtSummary.totalOutstanding(of: debts, payments: payments, direction: .lent)
            - DebtSummary.totalOutstanding(of: debts, payments: payments, direction: .borrowed)
    }
}

struct AssetHistoryPoint: Identifiable, Equatable {
    let date: Date
    let netWorth: Decimal
    /// What the assets were split into on that date, every group kept and always
    /// in the same order, so a chart of them keeps its bands in place from one
    /// month to the next.
    ///
    /// These add up to more than `netWorth` whenever anything is owed: what is
    /// borrowed and what is overdrawn are subtracted from the total but cannot
    /// be drawn as a band of assets.
    let composition: [AssetAllocationSlice]

    var id: Date { date }
}

/// Reconstructs month-end net worth from the dated records the app already
/// owns. Fund and gold positions use the catalogue's current price because the
/// store does not retain historical quotes.
///
/// Sales are dated and filtered like every other record, so a month that ended
/// before a position was closed still shows it held. That only works because a
/// sale is written as its own record: had it shrunk the lot instead, every past
/// month would silently be recomputed as though the position had never been
/// that large.
enum AssetHistory {
    private static let maximumMonthCount = 12

    static func points(
        accounts: [CashAccount],
        deposits: [SavingsDeposit],
        holdings: [FundHolding],
        instruments: [FundInstrument],
        transactions: [MoneyTransaction],
        transfers: [AccountTransfer],
        debts: [Debt],
        payments: [DebtPayment],
        sales: [FundSale],
        asOf: Date,
        calendar: Calendar = .current
    ) -> [AssetHistoryPoint] {
        guard
            let earliestDate = earliestDate(
                accounts: accounts,
                deposits: deposits,
                holdings: holdings,
                transactions: transactions,
                transfers: transfers,
                debts: debts,
                payments: payments,
                sales: sales
            ),
            earliestDate <= asOf,
            let currentMonthStart = calendar.dateInterval(of: .month, for: asOf)?.start,
            let windowStart = calendar.date(
                byAdding: .month,
                value: -(maximumMonthCount - 1),
                to: currentMonthStart
            )
        else {
            return []
        }

        return sampleDates(
            from: max(earliestDate, windowStart),
            through: asOf,
            calendar: calendar
        ).map { date in
            // Every figure on a point comes from the same filtered records, so
            // the bands and the line can never disagree about a month.
            let accounts = accounts.filter { $0.createdAt <= date }
            let deposits = deposits.filter { $0.openedAt <= date }
            let holdings = holdings.filter { $0.boughtOn <= date }
            let transactions = transactions.filter { $0.occurredAt <= date }
            let transfers = transfers.filter { $0.occurredAt <= date }
            let debts = debts.filter { $0.openedAt <= date }
            let payments = payments.filter { $0.occurredAt <= date }
            let sales = sales.filter { $0.soldAt <= date }

            return AssetHistoryPoint(
                date: date,
                netWorth: AssetSummary.netWorth(
                    accounts: accounts,
                    deposits: deposits,
                    holdings: holdings,
                    instruments: instruments,
                    transactions: transactions,
                    transfers: transfers,
                    debts: debts,
                    payments: payments,
                    sales: sales
                ),
                composition: AssetAllocation.amounts(
                    accounts: accounts,
                    deposits: deposits,
                    holdings: holdings,
                    instruments: instruments,
                    transactions: transactions,
                    transfers: transfers,
                    debts: debts,
                    payments: payments,
                    sales: sales
                )
            )
        }
    }

    private static func earliestDate(
        accounts: [CashAccount],
        deposits: [SavingsDeposit],
        holdings: [FundHolding],
        transactions: [MoneyTransaction],
        transfers: [AccountTransfer],
        debts: [Debt],
        payments: [DebtPayment],
        sales: [FundSale]
    ) -> Date? {
        var dates = accounts.map(\.createdAt)
        dates.append(contentsOf: deposits.map(\.openedAt))
        dates.append(contentsOf: holdings.map(\.boughtOn))
        dates.append(contentsOf: transactions.map(\.occurredAt))
        dates.append(contentsOf: transfers.map(\.occurredAt))
        dates.append(contentsOf: debts.map(\.openedAt))
        dates.append(contentsOf: payments.map(\.occurredAt))
        dates.append(contentsOf: sales.map(\.soldAt))
        return dates.min()
    }

    private static func sampleDates(
        from firstDate: Date,
        through asOf: Date,
        calendar: Calendar
    ) -> [Date] {
        var dates = [firstDate]
        guard var monthStart = calendar.dateInterval(of: .month, for: firstDate)?.start,
            let currentMonthStart = calendar.dateInterval(of: .month, for: asOf)?.start
        else {
            return dates
        }

        while monthStart < currentMonthStart {
            guard let nextMonth = calendar.date(byAdding: .month, value: 1, to: monthStart),
                let monthEnd = calendar.date(byAdding: .second, value: -1, to: nextMonth)
            else {
                break
            }

            if monthEnd > firstDate {
                dates.append(monthEnd)
            }
            monthStart = nextMonth
        }

        if dates.last != asOf {
            dates.append(asOf)
        }
        return dates
    }
}

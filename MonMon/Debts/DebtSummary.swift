import Foundation

enum DebtSummary {
    static func payments(for debt: Debt, payments: [DebtPayment]) -> [DebtPayment] {
        payments.filter { $0.debtID == debt.id }
    }

    static func paid(for debt: Debt, payments: [DebtPayment]) -> Decimal {
        payments.reduce(Decimal.zero) { total, payment in
            payment.debtID == debt.id ? total + payment.amount : total
        }
    }

    /// The principal minus what has been paid against it. Deliberately not
    /// clamped at zero: clamping would let a payment drop cash without dropping
    /// what is owed, and net worth would fall by the excess with no screen
    /// explaining why. `DebtPaymentDraft` refuses overpayment instead, so this
    /// can only go negative in a store edited by hand.
    static func outstanding(for debt: Debt, payments: [DebtPayment]) -> Decimal {
        debt.principal - paid(for: debt, payments: payments)
    }

    static func isSettled(_ debt: Debt, payments: [DebtPayment]) -> Bool {
        outstanding(for: debt, payments: payments) <= 0
    }

    /// Past the agreed date with something still owed. A settled debt is never
    /// overdue, and neither is one that agreed no date.
    static func isOverdue(_ debt: Debt, payments: [DebtPayment], asOf: Date) -> Bool {
        DebtInterest.isPastDue(dueDate: debt.dueDate, asOf: asOf)
            && outstanding(for: debt, payments: payments) > 0
    }

    /// How far a debt has come towards settled, from zero to one. A principal of
    /// zero cannot be reached through the form, but it is guarded here so no
    /// caller has to.
    static func progress(for debt: Debt, payments: [DebtPayment]) -> Decimal {
        guard debt.principal > 0 else { return .zero }

        let share = paid(for: debt, payments: payments) / debt.principal
        return min(max(share, .zero), 1)
    }

    static func totalPrincipal(of debts: [Debt], direction: DebtDirection) -> Decimal {
        debts.reduce(Decimal.zero) { total, debt in
            debt.direction == direction ? total + debt.principal : total
        }
    }

    /// What is still owed one way. The figure `AssetSummary.netWorth` and the
    /// Home doughnut use — never `totalDue`, so projected interest stays out of
    /// both.
    static func totalOutstanding(
        of debts: [Debt],
        payments: [DebtPayment],
        direction: DebtDirection
    ) -> Decimal {
        debts.reduce(Decimal.zero) { total, debt in
            guard debt.direction == direction else { return total }

            let remaining = outstanding(for: debt, payments: payments)
            return remaining > 0 ? total + remaining : total
        }
    }

    static func totalProjectedInterest(
        of debts: [Debt],
        direction: DebtDirection,
        asOf: Date
    ) -> Decimal {
        debts.reduce(Decimal.zero) { total, debt in
            debt.direction == direction ? total + debt.projectedInterest(asOf: asOf) : total
        }
    }

    /// What debts and their payments do to one account's balance: the signed
    /// principal of every debt opened through it, plus the signed amount of
    /// every payment made through it.
    ///
    /// Unlike `TransferSummary.netFlow` this does **not** sum to zero across
    /// accounts — the counterparty lives outside the app. That is exactly why
    /// `AssetSummary.netWorth` needs the outstanding balances as well: without
    /// them, borrowing would look like income.
    ///
    /// A payment naming no live debt is skipped rather than trapped: a `@Query`
    /// snapshot taken mid-delete can show one briefly.
    static func netFlow(
        for account: CashAccount,
        debts: [Debt],
        payments: [DebtPayment]
    ) -> Decimal {
        var directions: [UUID: DebtDirection] = [:]
        for debt in debts {
            directions[debt.id] = debt.direction
        }

        let openings = debts.reduce(Decimal.zero) { total, debt in
            total + debt.signedPrincipal(for: account.id)
        }

        return payments.reduce(openings) { total, payment in
            guard payment.accountID == account.id,
                let direction = directions[payment.debtID]
            else {
                return total
            }

            return total + payment.signedAmount(for: direction)
        }
    }

    /// Every debt and every payment that names this account, which is what the
    /// account deletion guard counts. A debt naming no account counts for none.
    static func count(
        for account: CashAccount,
        debts: [Debt],
        payments: [DebtPayment]
    ) -> Int {
        debts.filter { $0.accountID == account.id }.count
            + payments.filter { $0.accountID == account.id }.count
    }

    static func inRange(_ range: TransactionRange, debts: [Debt]) -> [Debt] {
        debts.filter { range.contains($0.openedAt) }
    }

    static func inRange(_ range: TransactionRange, payments: [DebtPayment]) -> [DebtPayment] {
        payments.filter { range.contains($0.occurredAt) }
    }
}

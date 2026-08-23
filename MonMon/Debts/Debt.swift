import Foundation
import SwiftData

/// One agreement to pay money back, in either direction. Borrowing puts money
/// into a cash account and creates a liability; lending takes it out and creates
/// an asset. Neither is income and neither is an expense, so a debt carries no
/// category and never reaches the Spending totals — the rule `AccountTransfer`
/// already follows.
@Model
final class Debt {
    var id: UUID = UUID()
    /// Who the money is owed to, or owed by. `direction` supplies the
    /// preposition, so one stored name serves both sides.
    var counterparty: String = ""
    var direction: DebtDirection = DebtDirection.borrowed
    /// Always positive. `direction` carries the direction, the same way
    /// `MoneyTransaction.amount` leans on `kind`.
    var principal: Decimal = Decimal.zero
    /// Percent per year, e.g. 12 for 12%. Zero is the common case — an
    /// interest-free loan from a relative — so a blank field means zero rather
    /// than making the owner type it.
    var annualInterestRate: Decimal = Decimal.zero
    var openedAt: Date = Date(timeIntervalSince1970: 0)
    /// When the balance falls due, if the two sides agreed on a date. `nil` for
    /// an open-ended loan, which most private ones are.
    var dueDate: Date?
    /// Identifier of the cash account the principal moved through, if any.
    /// Optional on purpose: a debt taken before this app existed is already
    /// inside an account's `openingBalance`, so naming an account would credit
    /// the same money twice. `nil` means the obligation is real and the cash
    /// movement is not this app's to record.
    var accountID: UUID?
    var note: String = ""
    var currencyCode: String = VNDCurrency.code
    var createdAt: Date = Date(timeIntervalSince1970: 0)

    init(
        id: UUID,
        counterparty: String,
        direction: DebtDirection,
        principal: Decimal,
        annualInterestRate: Decimal,
        openedAt: Date,
        dueDate: Date?,
        accountID: UUID?,
        note: String,
        currencyCode: String,
        createdAt: Date
    ) {
        self.id = id
        self.counterparty = counterparty
        self.direction = direction
        self.principal = principal
        self.annualInterestRate = annualInterestRate
        self.openedAt = openedAt
        self.dueDate = dueDate
        self.accountID = accountID
        self.note = note
        self.currencyCode = currencyCode
        self.createdAt = createdAt
    }
}

extension Debt {
    /// What opening this debt did to the account it names: positive when the
    /// money arrived, negative when it left. The shape
    /// `AccountTransfer.signedAmount(for:)` established.
    var signedPrincipal: Decimal {
        principal * direction.openingSign
    }

    /// The same figure, but zero for every account this debt does not name —
    /// including every account when the debt names none.
    func signedPrincipal(for accountID: UUID) -> Decimal {
        self.accountID == accountID ? signedPrincipal : .zero
    }

    /// How this debt reads on screen: "Borrowed from Anh Minh".
    var headline: String {
        "\(direction.displayName) \(direction.counterpartyPreposition) \(counterparty)"
    }

    /// Days the interest is projected over: the opening date to the due date, or
    /// to the day asked about when there is no due date. `asOf` is passed in
    /// rather than read from the clock so the figure is reproducible.
    func termDayCount(asOf: Date) -> Int {
        DebtInterest.dayCount(from: openedAt, to: dueDate ?? asOf)
    }

    /// Simple interest on the original principal. Projected only: it never joins
    /// what is outstanding and never reaches net worth, exactly as
    /// `SavingsDeposit.projectedInterest` is left out of `AssetSummary.netWorth`.
    ///
    /// It accrues on `principal`, not on what is left. Accruing on a shrinking
    /// balance would need every payment date weighted separately, which is an
    /// amortisation schedule wearing a different hat.
    func projectedInterest(asOf: Date) -> Decimal {
        DebtInterest.projected(
            principal: principal,
            annualRatePercent: annualInterestRate,
            from: openedAt,
            to: dueDate ?? asOf
        )
    }

    /// Principal plus projected interest — what changes hands if nothing is paid
    /// before the due date. The counterpart of `SavingsDeposit.maturityValue`.
    func totalDue(asOf: Date) -> Decimal {
        principal + projectedInterest(asOf: asOf)
    }
}

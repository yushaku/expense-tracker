import Foundation
import SwiftData

@Model
final class SavingsDeposit {
    var id: UUID = UUID()
    var name: String = ""
    var principal: Decimal = Decimal.zero
    var annualInterestRate: Decimal = Decimal.zero
    var termMonths: Int = 0
    var openedAt: Date = Date(timeIntervalSince1970: 0)
    var currencyCode: String = VNDCurrency.code
    var createdAt: Date = Date(timeIntervalSince1970: 0)
    /// Identifier of the cash account this deposit was funded from, if any.
    /// A stored id keeps the model flat; SwiftData relationships are not needed
    /// because accounts are never deleted in this slice.
    var sourceAccountID: UUID?

    init(
        id: UUID,
        name: String,
        principal: Decimal,
        annualInterestRate: Decimal,
        termMonths: Int,
        openedAt: Date,
        currencyCode: String,
        createdAt: Date,
        sourceAccountID: UUID? = nil
    ) {
        self.id = id
        self.name = name
        self.principal = principal
        self.annualInterestRate = annualInterestRate
        self.termMonths = termMonths
        self.openedAt = openedAt
        self.currencyCode = currencyCode
        self.createdAt = createdAt
        self.sourceAccountID = sourceAccountID
    }
}

extension SavingsDeposit {
    var maturityDate: Date {
        SavingsInterest.maturityDate(openedAt: openedAt, termMonths: termMonths)
    }

    var termDayCount: Int {
        SavingsInterest.dayCount(from: openedAt, to: maturityDate)
    }

    var projectedInterest: Decimal {
        SavingsInterest.projectedInterest(
            principal: principal,
            annualRatePercent: annualInterestRate,
            days: termDayCount
        )
    }

    var maturityValue: Decimal {
        principal + projectedInterest
    }
}

import Foundation
import Testing

@testable import MonMon

@Suite("Savings draft validation")
struct SavingsDraftTests {
    private let openedAt = Date(timeIntervalSince1970: 1_700_000_000)

    private func draft(
        name: String = "Techcombank 6 tháng",
        principalText: String = "100.000.000",
        rateText: String = "5,6",
        termMonthsText: String = "6",
        sourceAccountID: UUID? = nil
    ) -> SavingsDraft {
        SavingsDraft(
            name: name,
            principalText: principalText,
            rateText: rateText,
            termMonthsText: termMonthsText,
            openedAt: openedAt,
            sourceAccountID: sourceAccountID
        )
    }

    private func error(
        from draft: SavingsDraft,
        availableSourceBalance: Decimal? = nil
    ) -> SavingsFormError? {
        do {
            _ = try draft.validate(availableSourceBalance: availableSourceBalance)
            return nil
        } catch let error as SavingsFormError {
            return error
        } catch {
            return nil
        }
    }

    @Test("Valid input produces trimmed, parsed values")
    func validInputProducesValues() throws {
        let values = try draft(name: "  Techcombank 6 tháng  ")
            .validate(availableSourceBalance: nil)

        #expect(values.name == "Techcombank 6 tháng")
        #expect(values.principal == 100_000_000)
        #expect(values.annualInterestRate == Decimal(string: "5.6"))
        #expect(values.termMonths == 6)
        #expect(values.openedAt == openedAt)
    }

    @Test("An empty name is rejected")
    func emptyNameIsRejected() {
        #expect(error(from: draft(name: "   ")) == .emptyName)
    }

    @Test("A nonnumeric principal is rejected")
    func nonnumericPrincipalIsRejected() {
        #expect(error(from: draft(principalText: "một trăm triệu")) == .invalidPrincipal)
    }

    @Test("A zero or negative principal is rejected")
    func nonPositivePrincipalIsRejected() {
        #expect(error(from: draft(principalText: "0")) == .nonPositivePrincipal)
        #expect(error(from: draft(principalText: "-1.000")) == .nonPositivePrincipal)
    }

    @Test("A nonnumeric rate is rejected")
    func nonnumericRateIsRejected() {
        #expect(error(from: draft(rateText: "cao")) == .invalidRate)
    }

    @Test("A rate outside zero through one hundred is rejected")
    func rateOutOfRangeIsRejected() {
        #expect(error(from: draft(rateText: "-0,5")) == .rateOutOfRange)
        #expect(error(from: draft(rateText: "120")) == .rateOutOfRange)
    }

    @Test("A zero rate is allowed")
    func zeroRateIsAllowed() throws {
        let values = try draft(rateText: "0").validate(availableSourceBalance: nil)

        #expect(values.annualInterestRate == 0)
    }

    @Test("A nonnumeric term is rejected")
    func nonnumericTermIsRejected() {
        #expect(error(from: draft(termMonthsText: "sáu")) == .invalidTerm)
        #expect(error(from: draft(termMonthsText: "6,5")) == .invalidTerm)
    }

    @Test("A term outside one through one hundred twenty months is rejected")
    func termOutOfRangeIsRejected() {
        #expect(error(from: draft(termMonthsText: "0")) == .termOutOfRange)
        #expect(error(from: draft(termMonthsText: "121")) == .termOutOfRange)
    }

    @Test("A principal above the source balance is rejected")
    func principalAboveSourceBalanceIsRejected() {
        #expect(
            error(from: draft(), availableSourceBalance: 99_000_000)
                == .insufficientSourceBalance
        )
    }

    @Test("A principal equal to the source balance is allowed")
    func principalEqualToSourceBalanceIsAllowed() throws {
        let values = try draft().validate(availableSourceBalance: 100_000_000)

        #expect(values.principal == 100_000_000)
    }

    @Test("Source balance is ignored when no account funds the deposit")
    func sourceBalanceIsIgnoredWithoutAccount() throws {
        let values = try draft(principalText: "999.000.000")
            .validate(availableSourceBalance: nil)

        #expect(values.principal == 999_000_000)
    }

    @Test("A draft built from a deposit round-trips through validation")
    func draftFromDepositRoundTrips() throws {
        let sourceAccountID = UUID()
        let deposit = SavingsDeposit(
            id: UUID(),
            name: "VietinBank 12 tháng",
            principal: 250_000_000,
            annualInterestRate: Decimal(string: "6.1") ?? 0,
            termMonths: 12,
            openedAt: openedAt,
            currencyCode: VNDCurrency.code,
            createdAt: openedAt,
            sourceAccountID: sourceAccountID
        )

        let draft = SavingsDraft(deposit: deposit)
        let values = try draft.validate(availableSourceBalance: nil)

        #expect(draft.sourceAccountID == sourceAccountID)
        #expect(values.name == deposit.name)
        #expect(values.principal == deposit.principal)
        #expect(values.annualInterestRate == deposit.annualInterestRate)
        #expect(values.termMonths == deposit.termMonths)
    }
}

import Foundation
import Testing

@testable import MonMon

@Suite("Account draft validation")
@MainActor
struct AccountDraftTests {
    private let fixedID = UUID(
        uuid: (
            0x8B, 0x9F, 0x38, 0x8D, 0x0D, 0xF7, 0x4C, 0x70,
            0xA2, 0x69, 0x00, 0xC3, 0xF6, 0xA7, 0x54, 0xAF
        )
    )
    private let fixedDate = Date(timeIntervalSince1970: 1_700_000_000)

    @Test("Valid input trims the name and preserves every selected value")
    func validInputCreatesAnAccount() throws {
        let draft = AccountDraft(
            name: "  Salary account  ",
            kind: .bank,
            openingBalanceText: "12345678"
        )

        let account = try draft.makeAccount(id: fixedID, createdAt: fixedDate)

        #expect(account.id == fixedID)
        #expect(account.name == "Salary account")
        #expect(account.kind == .bank)
        #expect(account.openingBalance == Decimal(12_345_678))
        #expect(account.currencyCode == "VND")
        #expect(account.createdAt == fixedDate)
    }

    @Test("Vietnamese grouping separators parse exactly")
    func groupedBalanceParsesExactly() throws {
        let draft = AccountDraft(
            name: "Cash",
            openingBalanceText: "12.345.678"
        )

        let account = try draft.makeAccount(id: fixedID, createdAt: fixedDate)

        #expect(account.openingBalance == Decimal(12_345_678))
        #expect(account.kind == .cash)
    }

    @Test("Zero is a valid opening balance")
    func zeroBalanceIsValid() throws {
        let draft = AccountDraft(name: "Wallet", openingBalanceText: "0")

        let account = try draft.makeAccount(id: fixedID, createdAt: fixedDate)

        #expect(account.openingBalance == 0)
    }

    @Test("A whitespace-only name is rejected")
    func emptyNameIsRejected() {
        let draft = AccountDraft(name: "  \n  ", openingBalanceText: "1000")

        #expect(throws: AccountFormError.emptyName) {
            try draft.makeAccount(id: fixedID, createdAt: fixedDate)
        }
    }

    @Test("Nonnumeric balance input is rejected")
    func nonnumericBalanceIsRejected() {
        let draft = AccountDraft(name: "Wallet", openingBalanceText: "not money")

        #expect(throws: AccountFormError.invalidOpeningBalance) {
            try draft.makeAccount(id: fixedID, createdAt: fixedDate)
        }
    }

    @Test("A negative opening balance is rejected")
    func negativeBalanceIsRejected() {
        let draft = AccountDraft(name: "Wallet", openingBalanceText: "-1.000")

        #expect(throws: AccountFormError.negativeOpeningBalance) {
            try draft.makeAccount(id: fixedID, createdAt: fixedDate)
        }
    }

    @Test("VND display uses Vietnamese grouping and the dong symbol")
    func vndDisplayIsLocalized() {
        let formatted = VNDCurrency.format(Decimal(12_345_678))

        #expect(formatted.contains("12.345.678"))
        #expect(formatted.contains("₫"))
    }
}

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
            kind: .normal,
            openingBalanceText: "12345678"
        )

        let account = try draft.makeAccount(id: fixedID, createdAt: fixedDate)

        #expect(account.id == fixedID)
        #expect(account.name == "Salary account")
        #expect(account.kind == .normal)
        #expect(account.openingBalance == Decimal(12_345_678))
        #expect(account.creditLimit == 0)
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
        #expect(account.kind == .normal)
    }

    @Test("A new account starts at nought and saves on its name alone")
    func newDraftStartsAtZero() throws {
        var draft = AccountDraft()
        draft.name = "Wallet"

        let account = try draft.makeAccount(id: fixedID, createdAt: fixedDate)

        #expect(account.openingBalance == 0)
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

    @Test("Only Normal and Credit are selectable account kinds")
    func selectableAccountKindsAreCanonical() {
        #expect(CashAccountKind.allCases == [.normal, .credit])
    }

    @Test("Legacy Cash and Bank raw values decode as Normal")
    func legacyKindsDecodeAsNormal() throws {
        #expect(CashAccountKind(rawValue: "cash") == .normal)
        #expect(CashAccountKind(rawValue: "bank") == .normal)

        let decoded = try JSONDecoder().decode(
            CashAccountKind.self,
            from: Data(#""bank""#.utf8)
        )
        #expect(decoded == .normal)
        #expect(try JSONEncoder().encode(decoded) == Data(#""normal""#.utf8))
    }

    @Test("Credit limit parses exactly for a Credit account")
    func creditLimitParsesExactly() throws {
        let draft = AccountDraft(
            name: "Visa",
            kind: .credit,
            openingBalanceText: "-5.200.000",
            creditLimitText: "20.000.000"
        )

        let account = try draft.makeAccount(id: fixedID, createdAt: fixedDate)

        #expect(account.openingBalance == -5_200_000)
        #expect(account.creditLimit == 20_000_000)
    }

    @Test("Credit requires a numeric non-negative limit")
    func invalidCreditLimitIsRejected() {
        let nonnumeric = AccountDraft(
            name: "Visa",
            kind: .credit,
            openingBalanceText: "0",
            creditLimitText: "not money"
        )
        let negative = AccountDraft(
            name: "Visa",
            kind: .credit,
            openingBalanceText: "0",
            creditLimitText: "-1"
        )

        #expect(throws: AccountFormError.invalidCreditLimit) {
            try nonnumeric.makeAccount(id: fixedID, createdAt: fixedDate)
        }
        #expect(throws: AccountFormError.negativeCreditLimit) {
            try negative.makeAccount(id: fixedID, createdAt: fixedDate)
        }
    }

    @Test("Normal clears a stale Credit limit")
    func normalAccountClearsCreditLimit() throws {
        let account = CashAccount(
            id: fixedID,
            name: "Visa",
            kind: .credit,
            openingBalance: -1_000_000,
            creditLimit: 20_000_000,
            currencyCode: VNDCurrency.code,
            createdAt: fixedDate
        )
        let draft = AccountDraft(
            name: "Daily account",
            kind: .normal,
            openingBalanceText: "1.000.000",
            creditLimitText: "not visible"
        )

        try draft.apply(to: account)

        #expect(account.kind == .normal)
        #expect(account.creditLimit == 0)
    }

    @Test("VND display abbreviates with a Vietnamese decimal comma")
    func vndDisplayIsLocalized() {
        #expect(VNDCurrency.format(Decimal(12_345_678)) == "12,3M")
        #expect(VNDCurrency.formatPlain(Decimal(12_345_678)) == "12.345.678")
    }
}

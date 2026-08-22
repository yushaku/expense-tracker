import Foundation
import Testing

@testable import MonMon

@Suite("Cash balance summary")
@MainActor
struct CashBalanceSummaryTests {
    @Test("An empty account list has a zero total")
    func emptyListHasZeroTotal() {
        #expect(CashBalanceSummary.total(of: []) == 0)
    }

    @Test("One account contributes its exact opening balance")
    func oneAccountHasItsOpeningBalance() {
        let account = makeAccount(kind: .cash, openingBalance: Decimal(1_250_000))

        #expect(CashBalanceSummary.total(of: [account]) == Decimal(1_250_000))
    }

    @Test("Cash and bank balances add without floating-point conversion")
    func multipleAccountBalancesAddExactly() {
        let cash = makeAccount(kind: .cash, openingBalance: Decimal(1_250_000))
        let bank = makeAccount(kind: .bank, openingBalance: Decimal(8_750_000))

        #expect(CashBalanceSummary.total(of: [cash, bank]) == Decimal(10_000_000))
    }

    private func makeAccount(
        kind: CashAccountKind,
        openingBalance: Decimal
    ) -> CashAccount {
        CashAccount(
            id: UUID(
                uuid: (
                    0x8B, 0x9F, 0x38, 0x8D, 0x0D, 0xF7, 0x4C, 0x70,
                    0xA2, 0x69, 0x00, 0xC3, 0xF6, 0xA7, 0x54, 0xAF
                )
            ),
            name: "Account",
            kind: kind,
            openingBalance: openingBalance,
            currencyCode: "VND",
            createdAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
    }
}

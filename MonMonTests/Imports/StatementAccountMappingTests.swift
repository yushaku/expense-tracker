import Foundation
import Testing

@testable import MonMon

@Suite("Statement account mapping")
struct StatementAccountMappingTests {
    @Test("A successful commit remembers and resolves a current VND account")
    func successfulCommitRemembersAccount() throws {
        let fixture = try makeFixture()
        defer { fixture.remove() }
        let account = snapshot(currencyCode: VNDCurrency.code)

        #expect(
            fixture.mapping.remember(
                accountID: account.id,
                bank: .tpBank,
                accountLastFour: "1234",
                accounts: [account],
                financialCommitSucceeded: true
            )
        )
        #expect(
            fixture.mapping.resolve(
                bank: .tpBank,
                accountLastFour: "1234",
                accounts: [account]
            ) == account.id
        )
    }

    @Test("A failed commit does not change the remembered account")
    func failedCommitDoesNotWrite() throws {
        let fixture = try makeFixture()
        defer { fixture.remove() }
        let first = snapshot(currencyCode: VNDCurrency.code)
        let second = snapshot(currencyCode: VNDCurrency.code)
        #expect(
            fixture.mapping.remember(
                accountID: first.id,
                bank: .tpBank,
                accountLastFour: "1234",
                accounts: [first, second],
                financialCommitSucceeded: true
            )
        )

        #expect(
            !fixture.mapping.remember(
                accountID: second.id,
                bank: .tpBank,
                accountLastFour: "1234",
                accounts: [first, second],
                financialCommitSucceeded: false
            )
        )
        #expect(
            fixture.mapping.resolve(
                bank: .tpBank,
                accountLastFour: "1234",
                accounts: [first, second]
            ) == first.id
        )
    }

    @Test("Missing, malformed, stale, deleted, and non-VND mappings resolve nil")
    func invalidMappingsResolveNil() throws {
        let fixture = try makeFixture()
        defer { fixture.remove() }
        let valid = snapshot(currencyCode: VNDCurrency.code)
        let usd = snapshot(currencyCode: "USD")

        #expect(
            !fixture.mapping.remember(
                accountID: valid.id,
                bank: .tpBank,
                accountLastFour: nil,
                accounts: [valid],
                financialCommitSucceeded: true
            )
        )
        #expect(
            !fixture.mapping.remember(
                accountID: usd.id,
                bank: .tpBank,
                accountLastFour: "1234",
                accounts: [usd],
                financialCommitSucceeded: true
            )
        )

        fixture.defaults.set(
            ["tpbank|1234": "not-a-uuid"],
            forKey: StatementAccountMapping.storageKey
        )
        #expect(
            fixture.mapping.resolve(
                bank: .tpBank,
                accountLastFour: "1234",
                accounts: [valid]
            ) == nil
        )

        fixture.defaults.set(
            ["tpbank|1234": valid.id.uuidString],
            forKey: StatementAccountMapping.storageKey
        )
        #expect(
            fixture.mapping.resolve(
                bank: .tpBank,
                accountLastFour: "1234",
                accounts: []
            ) == nil
        )
        #expect(
            fixture.mapping.resolve(
                bank: .tpBank,
                accountLastFour: nil,
                accounts: [valid]
            ) == nil
        )
        #expect(
            fixture.mapping.resolve(
                bank: .tpBank,
                accountLastFour: "12-34",
                accounts: [valid]
            ) == nil
        )
    }

    @Test("Saving replaces only the exact bank and suffix mapping")
    func mappingsAreScopedToExactSuffix() throws {
        let fixture = try makeFixture()
        defer { fixture.remove() }
        let first = snapshot(currencyCode: VNDCurrency.code)
        let replacement = snapshot(currencyCode: VNDCurrency.code)

        let updates = [
            ("1234", first.id),
            ("5678", first.id),
            ("1234", replacement.id),
        ]
        for (suffix, accountID) in updates {
            #expect(
                fixture.mapping.remember(
                    accountID: accountID,
                    bank: .tpBank,
                    accountLastFour: suffix,
                    accounts: [first, replacement],
                    financialCommitSucceeded: true
                )
            )
        }

        #expect(
            fixture.mapping.resolve(
                bank: .tpBank,
                accountLastFour: "1234",
                accounts: [first, replacement]
            ) == replacement.id
        )
        #expect(
            fixture.mapping.resolve(
                bank: .tpBank,
                accountLastFour: "5678",
                accounts: [first, replacement]
            ) == first.id
        )
        #expect(
            fixture.mapping.resolve(
                bank: .tpBank,
                accountLastFour: "9999",
                accounts: [first, replacement]
            ) == nil
        )
    }

    private func snapshot(currencyCode: String) -> StatementImportAccountSnapshot {
        StatementImportAccountSnapshot(id: UUID(), currencyCode: currencyCode)
    }

    private func makeFixture() throws -> Fixture {
        let suiteName = "StatementAccountMappingTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        return Fixture(
            defaults: defaults,
            mapping: StatementAccountMapping(defaults: defaults),
            suiteName: suiteName
        )
    }

    private struct Fixture {
        let defaults: UserDefaults
        let mapping: StatementAccountMapping
        let suiteName: String

        func remove() {
            defaults.removePersistentDomain(forName: suiteName)
        }
    }
}

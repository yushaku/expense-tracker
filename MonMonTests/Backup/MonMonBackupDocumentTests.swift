import CryptoKit
import Foundation
import Testing

@testable import MonMon

@Suite("MonMon backup document")
struct MonMonBackupDocumentTests {
    private let earlierID = UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1))
    private let laterID = UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2))
    private let instant = Date(timeIntervalSince1970: 1_700_000_000.125)

    @Test("Portable scalars have one canonical representation")
    func canonicalScalars() throws {
        #expect(MonMonBackupScalar.uuid(laterID) == laterID.uuidString.lowercased())
        #expect(MonMonBackupScalar.decimal(Decimal(string: "1234.500")!) == "1234.5")
        #expect(MonMonBackupScalar.decimal(.zero) == "0")
        #expect(MonMonBackupScalar.date(instant) == "2023-11-14T22:13:20.125Z")

        #expect(try MonMonBackupScalar.parseUUID(MonMonBackupScalar.uuid(laterID)) == laterID)
        #expect(try MonMonBackupScalar.parseDecimal("1234.5") == Decimal(string: "1234.5"))
        #expect(throws: MonMonBackupScalarError.invalidDecimal) {
            try MonMonBackupScalar.parseDecimal("NaN")
        }
        #expect(try MonMonBackupScalar.parseDate("2023-11-14T22:13:20.125Z") == instant)
    }

    @Test("A document round trips with metadata and checksum")
    func roundTrip() throws {
        var payload = MonMonBackupPayload.empty
        payload.accounts = [account(id: laterID, name: "Wallet")]

        let document = try MonMonBackupDocument.make(
            payload: payload,
            exportedAt: instant,
            appVersion: "1.2.3",
            flavour: .dev
        )
        let data = try MonMonBackupCodec.encode(document)
        let decoded = try MonMonBackupCodec.decode(data)

        #expect(decoded == document)
        #expect(decoded.format == "monmon-backup")
        #expect(decoded.formatVersion == 1)
        #expect(decoded.exportedAt == "2023-11-14T22:13:20.125Z")
        #expect(decoded.payloadSHA256.count == 64)
        #expect(decoded.payload.accounts.single?.name == "Wallet")
    }

    @Test("Document creation sorts records deterministically")
    func deterministicOrdering() throws {
        var firstPayload = MonMonBackupPayload.empty
        firstPayload.accounts = [
            account(id: laterID, name: "Later"),
            account(id: earlierID, name: "Earlier"),
        ]
        var secondPayload = MonMonBackupPayload.empty
        secondPayload.accounts = Array(firstPayload.accounts.reversed())

        let first = try MonMonBackupDocument.make(
            payload: firstPayload,
            exportedAt: instant,
            appVersion: "1",
            flavour: .dev
        )
        let second = try MonMonBackupDocument.make(
            payload: secondPayload,
            exportedAt: instant,
            appVersion: "1",
            flavour: .dev
        )

        #expect(try MonMonBackupCodec.encode(first) == MonMonBackupCodec.encode(second))
        #expect(
            first.payload.accounts.map(\.id) == [
                MonMonBackupScalar.uuid(earlierID),
                MonMonBackupScalar.uuid(laterID),
            ])
    }

    @Test("A legacy account record without a Credit limit still decodes")
    func legacyAccountRecordDecodes() throws {
        let data = Data(
            #"""
            {
              "id": "00000000-0000-0000-0000-000000000001",
              "name": "Wallet",
              "kind": "cash",
              "openingBalance": "1000",
              "currencyCode": "VND",
              "createdAt": "2023-11-14T22:13:20.125Z"
            }
            """#.utf8
        )

        let record = try JSONDecoder().decode(
            MonMonBackupPayload.AccountRecord.self,
            from: data
        )

        #expect(record.kind == "cash")
        #expect(record.creditLimit == nil)
    }

    @Test("A legacy payload without budget jars still decodes")
    func legacyPayloadWithoutBudgetJarsDecodes() throws {
        let data = try JSONEncoder().encode(LegacyPayload.empty)

        let payload = try JSONDecoder().decode(MonMonBackupPayload.self, from: data)

        #expect(payload.budgetJars.isEmpty)
        #expect(payload.goals.isEmpty)
    }

    @Test("A signed legacy document without budget jars still validates")
    func signedLegacyDocumentValidates() throws {
        let payload = LegacyPayload.empty
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        let digest = SHA256.hash(data: try encoder.encode(payload))
            .map { String(format: "%02x", $0) }
            .joined()
        let legacy = LegacyDocument(
            format: MonMonBackupDocument.currentFormat,
            formatVersion: MonMonBackupDocument.currentVersion,
            exportedAt: MonMonBackupScalar.date(instant),
            appVersion: "1.0",
            flavour: .dev,
            payload: payload,
            payloadSHA256: digest
        )

        let validated = try MonMonBackupValidator.decodeAndValidate(
            encoder.encode(legacy),
            expectedFlavour: .dev
        )

        #expect(validated.payload.budgetJars.isEmpty)
        #expect(validated.payload.goals.isEmpty)
    }

    private func account(id: UUID, name: String) -> MonMonBackupPayload.AccountRecord {
        MonMonBackupPayload.AccountRecord(
            id: MonMonBackupScalar.uuid(id),
            name: name,
            kind: "cash",
            openingBalance: "1000",
            creditLimit: "0",
            currencyCode: "VND",
            createdAt: MonMonBackupScalar.date(instant)
        )
    }
}

private struct LegacyPayload: Encodable {
    var accounts: [MonMonBackupPayload.AccountRecord]
    var savingsDeposits: [MonMonBackupPayload.SavingsDepositRecord]
    var savingsWithdrawals: [MonMonBackupPayload.SavingsWithdrawalRecord]
    var fundInstruments: [MonMonBackupPayload.FundInstrumentRecord]
    var fundHoldings: [MonMonBackupPayload.FundHoldingRecord]
    var fundSales: [MonMonBackupPayload.FundSaleRecord]
    var categories: [MonMonBackupPayload.CategoryRecord]
    var transactions: [MonMonBackupPayload.TransactionRecord]
    var pendingCaptures: [MonMonBackupPayload.PendingCaptureRecord]
    var transfers: [MonMonBackupPayload.TransferRecord]
    var debts: [MonMonBackupPayload.DebtRecord]
    var debtPayments: [MonMonBackupPayload.DebtPaymentRecord]
    var recurringRules: [MonMonBackupPayload.RecurringRuleRecord]
    var preferences: MonMonBackupPayload.Preferences

    static let empty = LegacyPayload(
        accounts: [],
        savingsDeposits: [],
        savingsWithdrawals: [],
        fundInstruments: [],
        fundHoldings: [],
        fundSales: [],
        categories: [],
        transactions: [],
        pendingCaptures: [],
        transfers: [],
        debts: [],
        debtPayments: [],
        recurringRules: [],
        preferences: .empty
    )
}

private struct LegacyDocument: Encodable {
    var format: String
    var formatVersion: Int
    var exportedAt: String
    var appVersion: String
    var flavour: MonMonBackupFlavour
    var payload: LegacyPayload
    var payloadSHA256: String
}

extension Array {
    fileprivate var single: Element? {
        count == 1 ? first : nil
    }
}

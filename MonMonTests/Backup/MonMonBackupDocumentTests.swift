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

extension Array {
    fileprivate var single: Element? {
        count == 1 ? first : nil
    }
}

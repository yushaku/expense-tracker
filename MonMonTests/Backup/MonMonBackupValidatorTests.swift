import Foundation
import Testing

@testable import MonMon

@Suite("MonMon backup validation")
struct MonMonBackupValidatorTests {
    private let instant = Date(timeIntervalSince1970: 1_700_000_000.125)
    private let accountID = UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1))
    private let otherID = UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2))

    @Test("A valid document returns a content-safe preview")
    func validPreview() throws {
        var payload = MonMonBackupPayload.empty
        payload.accounts = [account(id: accountID)]
        let document = try signed(payload)

        let validated = try MonMonBackupValidator.validate(document, expectedFlavour: .dev)

        #expect(validated.preview.exportedAt == instant)
        #expect(validated.preview.appVersion == "1.0")
        #expect(validated.preview.flavour == .dev)
        #expect(validated.preview.counts.accounts == 1)
        #expect(validated.preview.incomingRecordCount == 1)
        #expect(validated.warnings.isEmpty)
    }

    @Test("Input size, format, version, flavour, and checksum block validation")
    func envelopeFailures() throws {
        let valid = try signed(.empty)

        #expect(throws: MonMonBackupValidationError.fileTooLarge) {
            try MonMonBackupValidator.decodeAndValidate(
                Data(repeating: 0, count: 11),
                expectedFlavour: .dev,
                maximumByteCount: 10
            )
        }

        var wrongFormat = valid
        wrongFormat.format = "other"
        #expect(throws: MonMonBackupValidationError.unsupportedFormat) {
            try MonMonBackupValidator.validate(wrongFormat, expectedFlavour: .dev)
        }

        var newerVersion = valid
        newerVersion.formatVersion = 2
        #expect(throws: MonMonBackupValidationError.unsupportedVersion) {
            try MonMonBackupValidator.validate(newerVersion, expectedFlavour: .dev)
        }

        #expect(throws: MonMonBackupValidationError.wrongFlavour) {
            try MonMonBackupValidator.validate(valid, expectedFlavour: .prod)
        }

        var damaged = valid
        damaged.payloadSHA256 = String(repeating: "0", count: 64)
        #expect(throws: MonMonBackupValidationError.checksumMismatch) {
            try MonMonBackupValidator.validate(damaged, expectedFlavour: .dev)
        }
    }

    @Test("File reads stop at the byte limit")
    func boundedFileRead() throws {
        let url = FileManager.default.temporaryDirectory
            .appending(path: "monmon-bounded-read-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: url) }
        try Data(repeating: 0, count: 11).write(to: url)

        #expect(throws: MonMonBackupValidationError.fileTooLarge) {
            try MonMonBackupFileReader.read(url, maximumByteCount: 10)
        }

        try Data("valid".utf8).write(to: url)
        #expect(try MonMonBackupFileReader.read(url, maximumByteCount: 10) == Data("valid".utf8))
    }

    @Test("Malformed scalars, enums, and duplicate IDs are rejected")
    func structuralFailures() throws {
        var malformed = MonMonBackupPayload.empty
        var record = account(id: accountID)
        record.openingBalance = "01"
        malformed.accounts = [record]
        #expect(throws: MonMonBackupValidationError.invalidPayload) {
            try MonMonBackupValidator.validate(try signed(malformed), expectedFlavour: .dev)
        }

        var unknownEnum = MonMonBackupPayload.empty
        record = account(id: accountID)
        record.kind = "unknown"
        unknownEnum.accounts = [record]
        #expect(throws: MonMonBackupValidationError.invalidPayload) {
            try MonMonBackupValidator.validate(try signed(unknownEnum), expectedFlavour: .dev)
        }

        var duplicate = MonMonBackupPayload.empty
        duplicate.accounts = [account(id: accountID), account(id: accountID)]
        #expect(throws: MonMonBackupValidationError.duplicateIdentifier) {
            try MonMonBackupValidator.validate(try signed(duplicate), expectedFlavour: .dev)
        }
    }

    @Test("A Credit limit must be a canonical non-negative amount")
    func invalidCreditLimitIsRejected() throws {
        var payload = MonMonBackupPayload.empty
        var record = account(id: accountID)
        record.creditLimit = "-1"
        payload.accounts = [record]

        #expect(throws: MonMonBackupValidationError.invalidPayload) {
            try MonMonBackupValidator.validate(try signed(payload), expectedFlavour: .dev)
        }
    }

    @Test("Missing required account references and impossible transfers are rejected")
    func referenceFailures() throws {
        var payload = MonMonBackupPayload.empty
        payload.accounts = [account(id: accountID)]
        payload.transfers = [
            MonMonBackupPayload.TransferRecord(
                id: MonMonBackupScalar.uuid(otherID),
                amount: "100",
                occurredAt: MonMonBackupScalar.date(instant),
                note: "",
                sourceAccountID: MonMonBackupScalar.uuid(accountID),
                destinationAccountID: MonMonBackupScalar.uuid(otherID),
                currencyCode: "VND",
                createdAt: MonMonBackupScalar.date(instant),
                sourceAccountImportID: nil,
                destinationAccountImportID: nil
            )
        ]

        #expect(throws: MonMonBackupValidationError.invalidReference) {
            try MonMonBackupValidator.validate(try signed(payload), expectedFlavour: .dev)
        }

        payload.accounts.append(account(id: otherID))
        payload.transfers[0].destinationAccountID = MonMonBackupScalar.uuid(accountID)
        #expect(throws: MonMonBackupValidationError.invalidPayload) {
            try MonMonBackupValidator.validate(try signed(payload), expectedFlavour: .dev)
        }
    }

    @Test("Stale optional preferences are cleared with a warning")
    func stalePreferences() throws {
        var payload = MonMonBackupPayload.empty
        payload.accounts = [account(id: accountID)]
        payload.preferences.defaultAccountID = MonMonBackupScalar.uuid(otherID)
        payload.preferences.statementAccountMappings = [
            "tpbank|1234": MonMonBackupScalar.uuid(otherID)
        ]

        let validated = try MonMonBackupValidator.validate(
            try signed(payload),
            expectedFlavour: .dev
        )

        #expect(validated.payload.preferences.defaultAccountID == nil)
        #expect(validated.payload.preferences.statementAccountMappings.isEmpty)
        #expect(validated.warnings.contains(.stalePreferences))
    }

    private func signed(_ payload: MonMonBackupPayload) throws -> MonMonBackupDocument {
        try MonMonBackupDocument.make(
            payload: payload,
            exportedAt: instant,
            appVersion: "1.0",
            flavour: .dev
        )
    }

    private func account(id: UUID) -> MonMonBackupPayload.AccountRecord {
        MonMonBackupPayload.AccountRecord(
            id: MonMonBackupScalar.uuid(id),
            name: "Synthetic account",
            kind: "bank",
            openingBalance: "1000",
            currencyCode: "VND",
            createdAt: MonMonBackupScalar.date(instant)
        )
    }
}

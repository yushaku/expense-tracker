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

    @Test("A Normal account cannot carry borrowing capacity")
    func normalAccountCreditLimitIsRejected() throws {
        var payload = MonMonBackupPayload.empty
        var record = account(id: accountID)
        record.kind = CashAccountKind.normal.rawValue
        record.creditLimit = "1"
        payload.accounts = [record]

        #expect(throws: MonMonBackupValidationError.invalidPayload) {
            try MonMonBackupValidator.validate(try signed(payload), expectedFlavour: .dev)
        }
    }

    @Test("Budget jar roles, allocation, and category references are validated")
    func invalidBudgetJarDataIsRejected() throws {
        var payload = MonMonBackupPayload.empty
        payload.budgetJars = [budgetJar(id: accountID, role: .custom)]
        payload.budgetJars[0].role = "unknown"

        #expect(throws: MonMonBackupValidationError.invalidPayload) {
            try MonMonBackupValidator.validate(try signed(payload), expectedFlavour: .dev)
        }

        payload.budgetJars = [
            budgetJar(id: accountID, role: .custom),
            budgetJar(id: UUID(), role: .investment),
            budgetJar(id: UUID(), role: .savings),
        ]
        payload.categories = [
            MonMonBackupPayload.CategoryRecord(
                id: MonMonBackupScalar.uuid(otherID),
                name: "Food",
                kind: TransactionKind.expense.rawValue,
                symbolName: "fork.knife",
                colorName: "green",
                createdAt: MonMonBackupScalar.date(instant),
                budgetJarID: MonMonBackupScalar.uuid(UUID())
            )
        ]

        #expect(throws: MonMonBackupValidationError.invalidReference) {
            try MonMonBackupValidator.validate(try signed(payload), expectedFlavour: .dev)
        }
    }

    @Test("Goal values and funding jar references are validated")
    func invalidGoalDataIsRejected() throws {
        let investmentJarID = UUID()
        let savingsJarID = UUID()
        var payload = MonMonBackupPayload.empty
        payload.budgetJars = [
            budgetJar(id: accountID, role: .custom),
            budgetJar(id: investmentJarID, role: .investment),
            budgetJar(id: savingsJarID, role: .savings),
        ]
        payload.goals = [goal(id: otherID, jarID: savingsJarID)]
        payload.goals[0].kind = "unknown"

        #expect(throws: MonMonBackupValidationError.invalidPayload) {
            try MonMonBackupValidator.validate(try signed(payload), expectedFlavour: .dev)
        }

        payload.goals[0].kind = FinancialGoalKind.trip.rawValue
        payload.goals[0].fundingJarID = MonMonBackupScalar.uuid(UUID())
        #expect(throws: MonMonBackupValidationError.invalidReference) {
            try MonMonBackupValidator.validate(try signed(payload), expectedFlavour: .dev)
        }

        payload.goals[0].fundingJarID = MonMonBackupScalar.uuid(savingsJarID)
        payload.goals[0].earmarkedAmount = "1001"
        #expect(throws: MonMonBackupValidationError.invalidPayload) {
            try MonMonBackupValidator.validate(try signed(payload), expectedFlavour: .dev)
        }
    }

    @Test("Income allocation snapshots must be valid and match an income amount")
    @MainActor
    func invalidIncomeAllocationSnapshotIsRejected() throws {
        let categoryID = UUID()
        let snapshot = try makeIncomeSnapshot(amount: 100)
        var payload = MonMonBackupPayload.empty
        payload.accounts = [account(id: accountID)]
        payload.categories = [
            MonMonBackupPayload.CategoryRecord(
                id: MonMonBackupScalar.uuid(categoryID),
                name: "Salary",
                kind: TransactionKind.income.rawValue,
                symbolName: "banknote.fill",
                colorName: "green",
                createdAt: MonMonBackupScalar.date(instant),
                budgetJarID: nil
            )
        ]
        payload.transactions = [
            transaction(
                kind: .income,
                amount: "100",
                categoryID: categoryID,
                snapshot: snapshot
            )
        ]

        _ = try MonMonBackupValidator.validate(try signed(payload), expectedFlavour: .dev)

        payload.transactions[0].incomeAllocationSnapshot = "not-json"
        #expect(throws: MonMonBackupValidationError.invalidPayload) {
            try MonMonBackupValidator.validate(try signed(payload), expectedFlavour: .dev)
        }

        payload.transactions[0] = transaction(
            kind: .expense,
            amount: "100",
            categoryID: categoryID,
            snapshot: snapshot
        )
        #expect(throws: MonMonBackupValidationError.invalidPayload) {
            try MonMonBackupValidator.validate(try signed(payload), expectedFlavour: .dev)
        }

        payload.transactions[0] = transaction(
            kind: .income,
            amount: "101",
            categoryID: categoryID,
            snapshot: snapshot
        )
        #expect(throws: MonMonBackupValidationError.invalidPayload) {
            try MonMonBackupValidator.validate(try signed(payload), expectedFlavour: .dev)
        }
    }

    @Test("Trip records and transaction routing enforce structural invariants")
    func invalidTripDataIsRejected() throws {
        var payload = MonMonBackupPayload.empty
        payload.tripWorkspaces = [tripWorkspace()]

        _ = try MonMonBackupValidator.validate(try signed(payload), expectedFlavour: .dev)

        payload.tripWorkspaces[0].status = "unknown"
        #expect(throws: MonMonBackupValidationError.invalidPayload) {
            try MonMonBackupValidator.validate(try signed(payload), expectedFlavour: .dev)
        }

        payload.tripWorkspaces[0] = tripWorkspace()
        payload.tripWorkspaces[0].budgetAmount = "0"
        #expect(throws: MonMonBackupValidationError.invalidPayload) {
            try MonMonBackupValidator.validate(try signed(payload), expectedFlavour: .dev)
        }

        payload.tripWorkspaces[0] = tripWorkspace(status: .completed, completedAt: nil)
        #expect(throws: MonMonBackupValidationError.invalidPayload) {
            try MonMonBackupValidator.validate(try signed(payload), expectedFlavour: .dev)
        }
    }

    @Test("Trip optional references warn while impossible transaction routing is rejected")
    func tripReferenceAndRoutingValidation() throws {
        let tripID = UUID()
        var payload = MonMonBackupPayload.empty
        payload.accounts = [account(id: accountID)]
        payload.tripWorkspaces = [
            tripWorkspace(
                id: tripID,
                sourceGoalID: UUID(),
                fundingJarID: UUID()
            )
        ]
        payload.transactions = [
            MonMonBackupPayload.TransactionRecord(
                id: MonMonBackupScalar.uuid(otherID),
                kind: TransactionKind.expense.rawValue,
                amount: "100",
                occurredAt: MonMonBackupScalar.date(instant),
                note: "Hotel",
                accountID: MonMonBackupScalar.uuid(accountID),
                categoryID: nil,
                sourceRuleID: nil,
                currencyCode: VNDCurrency.code,
                createdAt: MonMonBackupScalar.date(instant),
                sourceImportID: nil,
                incomeAllocationSnapshot: nil,
                tripWorkspaceID: MonMonBackupScalar.uuid(tripID),
                budgetJarOverrideID: MonMonBackupScalar.uuid(UUID())
            )
        ]

        let validated = try MonMonBackupValidator.validate(
            try signed(payload),
            expectedFlavour: .dev
        )
        #expect(validated.warnings.contains(.danglingOptionalReferences))

        payload.transactions[0].kind = TransactionKind.income.rawValue
        #expect(throws: MonMonBackupValidationError.invalidPayload) {
            try MonMonBackupValidator.validate(try signed(payload), expectedFlavour: .dev)
        }

        payload.transactions[0].kind = TransactionKind.expense.rawValue
        payload.transactions[0].tripWorkspaceID = nil
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

    private func budgetJar(
        id: UUID,
        role: BudgetJarRole
    ) -> MonMonBackupPayload.BudgetJarRecord {
        MonMonBackupPayload.BudgetJarRecord(
            id: MonMonBackupScalar.uuid(id),
            name: "Necessities",
            allocationPercent: role == .custom ? "55" : "10",
            role: role.rawValue,
            symbolName: "house.fill",
            colorName: "blue",
            createdAt: MonMonBackupScalar.date(instant)
        )
    }

    private func goal(id: UUID, jarID: UUID) -> MonMonBackupPayload.GoalRecord {
        MonMonBackupPayload.GoalRecord(
            id: MonMonBackupScalar.uuid(id),
            name: "Trip",
            kind: FinancialGoalKind.trip.rawValue,
            targetAmount: "1000",
            earmarkedAmount: "100",
            targetDate: MonMonBackupScalar.date(instant.addingTimeInterval(31_536_000)),
            monthlyContribution: "100",
            fundingJarID: MonMonBackupScalar.uuid(jarID),
            symbolName: "airplane",
            colorName: "sky",
            createdAt: MonMonBackupScalar.date(instant)
        )
    }

    private func transaction(
        kind: TransactionKind,
        amount: String,
        categoryID: UUID,
        snapshot: String?
    ) -> MonMonBackupPayload.TransactionRecord {
        MonMonBackupPayload.TransactionRecord(
            id: MonMonBackupScalar.uuid(otherID),
            kind: kind.rawValue,
            amount: amount,
            occurredAt: MonMonBackupScalar.date(instant),
            note: "Salary",
            accountID: MonMonBackupScalar.uuid(accountID),
            categoryID: MonMonBackupScalar.uuid(categoryID),
            sourceRuleID: nil,
            currencyCode: VNDCurrency.code,
            createdAt: MonMonBackupScalar.date(instant),
            sourceImportID: nil,
            incomeAllocationSnapshot: snapshot
        )
    }

    private func tripWorkspace(
        id: UUID = UUID(),
        sourceGoalID: UUID? = nil,
        fundingJarID: UUID? = nil,
        status: TripWorkspaceStatus = .active,
        completedAt: Date? = nil
    ) -> MonMonBackupPayload.TripWorkspaceRecord {
        MonMonBackupPayload.TripWorkspaceRecord(
            id: MonMonBackupScalar.uuid(id),
            sourceGoalID: sourceGoalID.map(MonMonBackupScalar.uuid),
            name: "Japan",
            budgetAmount: "1000",
            fundingJarID: fundingJarID.map(MonMonBackupScalar.uuid),
            symbolName: "airplane",
            colorName: "sky",
            status: status.rawValue,
            startedAt: MonMonBackupScalar.date(instant),
            completedAt: completedAt.map(MonMonBackupScalar.date),
            createdAt: MonMonBackupScalar.date(instant)
        )
    }

    @MainActor
    private func makeIncomeSnapshot(amount: Decimal) throws -> String {
        let jar = BudgetJar(
            id: UUID(),
            name: "Savings",
            allocationPercent: 100,
            role: .savings,
            symbolName: "building.columns.fill",
            colorName: "yellow",
            createdAt: instant
        )
        return try IncomeAllocationSnapshotCodec.encode(
            IncomeAllocationSnapshot.capture(
                amount: amount,
                jars: [jar],
                capturedAt: instant,
                isEstimated: false
            )
        )
    }
}

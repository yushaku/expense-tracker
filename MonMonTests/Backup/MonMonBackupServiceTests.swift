import Foundation
import SwiftData
import Testing

@testable import MonMon

@Suite("MonMon backup service")
@MainActor
struct MonMonBackupServiceTests {
    private let instant = Date(timeIntervalSince1970: 1_700_000_000.125)
    private let importedSource = String(repeating: "a", count: 64)

    @Test("Export captures every model and approved preference")
    func exportsCompleteSnapshot() throws {
        let container = try makeContainer()
        let defaults = makeDefaults()
        let fixture = try insertCompleteFixture(in: container.mainContext)
        defaults.set(AppTheme.dark.rawValue, forKey: AppTheme.storageKey)
        defaults.set(AppLanguage.vietnamese.rawValue, forKey: AppLanguage.storageKey)
        defaults.set(fixture.bankID.uuidString, forKey: TransactionDefaults.accountStorageKey)
        defaults.set(fixture.categoryID.uuidString, forKey: TransactionDefaults.categoryStorageKey)
        defaults.set(
            ["tpbank|1234": fixture.bankID.uuidString],
            forKey: StatementAccountMapping.storageKey
        )

        let document = try service(container: container, defaults: defaults).makeDocument(
            exportedAt: instant,
            appVersion: "1.0",
            flavour: .dev
        )
        let validated = try MonMonBackupValidator.validate(document, expectedFlavour: .dev)

        #expect(validated.payload.accounts.count == 2)
        let credit = try #require(
            validated.payload.accounts.first {
                $0.id == MonMonBackupScalar.uuid(fixture.bankID)
            }
        )
        #expect(credit.kind == "credit")
        #expect(credit.creditLimit == "20000")
        let normal = try #require(
            validated.payload.accounts.first {
                $0.id == MonMonBackupScalar.uuid(fixture.walletID)
            }
        )
        #expect(normal.kind == "normal")
        #expect(normal.creditLimit == "0")
        #expect(validated.payload.savingsDeposits.count == 1)
        #expect(validated.payload.savingsWithdrawals.count == 1)
        #expect(validated.payload.fundInstruments.count == 1)
        #expect(validated.payload.fundHoldings.count == 1)
        #expect(validated.payload.fundSales.count == 1)
        #expect(validated.payload.categories.count == 1)
        #expect(validated.payload.transactions.count == 1)
        #expect(validated.payload.pendingCaptures.count == 1)
        #expect(validated.payload.transfers.count == 1)
        #expect(validated.payload.debts.count == 1)
        #expect(validated.payload.debtPayments.count == 1)
        #expect(validated.payload.recurringRules.count == 1)
        #expect(validated.payload.recordCount == 14)
        #expect(validated.payload.transactions.single?.sourceImportID == importedSource)
        #expect(validated.payload.preferences.theme == AppTheme.dark.rawValue)
        #expect(validated.payload.preferences.language == AppLanguage.vietnamese.rawValue)
        #expect(
            validated.payload.preferences.defaultAccountID
                == MonMonBackupScalar.uuid(fixture.bankID)
        )
        #expect(
            validated.payload.preferences.statementAccountMappings["tpbank|1234"]
                == MonMonBackupScalar.uuid(fixture.bankID)
        )
        #expect(
            defaults.string(forKey: TransactionDefaults.accountStorageKey)
                == fixture.bankID.uuidString
        )
        #expect(try container.mainContext.fetchCount(FetchDescriptor<MoneyTransaction>()) == 1)
    }

    @Test("Restore replaces every model, writes preferences, and is idempotent")
    func restoresCompleteSnapshot() throws {
        let sourceContainer = try makeContainer()
        let sourceDefaults = makeDefaults()
        let fixture = try insertCompleteFixture(in: sourceContainer.mainContext)
        sourceDefaults.set(fixture.bankID.uuidString, forKey: TransactionDefaults.accountStorageKey)
        let incoming = try service(container: sourceContainer, defaults: sourceDefaults)
            .makeDocument(
                exportedAt: instant,
                appVersion: "1.0",
                flavour: .dev
            )
        let validated = try MonMonBackupValidator.validate(incoming, expectedFlavour: .dev)

        let destination = try makeContainer()
        let destinationDefaults = makeDefaults()
        destinationDefaults.set("keep-until-success", forKey: AppTheme.storageKey)
        destination.mainContext.insert(
            CashAccount(
                id: UUID(),
                name: "Old account",
                kind: .normal,
                openingBalance: 99,
                currencyCode: VNDCurrency.code,
                createdAt: instant.addingTimeInterval(-100)
            )
        )
        try destination.mainContext.save()
        let recoveryURL = temporaryRecoveryURL()
        defer { try? FileManager.default.removeItem(at: recoveryURL) }
        let restoreService = service(
            container: destination,
            defaults: destinationDefaults,
            recoveryURL: recoveryURL
        )

        let report = try restoreService.restore(validated)

        #expect(report.restoredRecordCount == 14)
        #expect(try destination.mainContext.fetchCount(FetchDescriptor<CashAccount>()) == 2)
        let restoredCredit = try #require(
            destination.mainContext.fetch(FetchDescriptor<CashAccount>()).first {
                $0.id == fixture.bankID
            }
        )
        #expect(restoredCredit.creditLimit == 20_000)
        #expect(try destination.mainContext.fetchCount(FetchDescriptor<MoneyTransaction>()) == 1)
        #expect(try destination.mainContext.fetchCount(FetchDescriptor<RecurringRule>()) == 1)
        #expect(
            destinationDefaults.string(forKey: TransactionDefaults.accountStorageKey)
                == fixture.bankID.uuidString
        )

        let recovery = try restoreService.loadRecovery()
        #expect(recovery.preview.counts.accounts == 1)
        #expect(recovery.payload.accounts.single?.name == "Old account")

        _ = try restoreService.restore(validated)
        let afterSecondRestore = try restoreService.makeDocument(
            exportedAt: instant,
            appVersion: "1.0",
            flavour: .dev
        )
        #expect(afterSecondRestore.payload == incoming.payload)
    }

    @Test("A failed save rolls back data and leaves preferences unchanged")
    func saveFailureRollsBack() throws {
        enum SyntheticFailure: Error { case save }

        let source = try makeContainer()
        _ = try insertCompleteFixture(in: source.mainContext)
        let incoming = try service(container: source, defaults: makeDefaults()).makeDocument(
            exportedAt: instant,
            appVersion: "1.0",
            flavour: .dev
        )
        let validated = try MonMonBackupValidator.validate(incoming, expectedFlavour: .dev)

        let destination = try makeContainer()
        let defaults = makeDefaults()
        defaults.set("original", forKey: AppTheme.storageKey)
        let oldID = UUID()
        destination.mainContext.insert(
            CashAccount(
                id: oldID,
                name: "Old",
                kind: .normal,
                openingBalance: 1,
                currencyCode: VNDCurrency.code,
                createdAt: instant
            )
        )
        try destination.mainContext.save()
        let recoveryURL = temporaryRecoveryURL()
        defer { try? FileManager.default.removeItem(at: recoveryURL) }
        let failing = MonMonBackupService(
            container: destination,
            defaults: defaults,
            recoveryURL: recoveryURL,
            save: { _ in throw SyntheticFailure.save }
        )

        #expect(throws: MonMonBackupServiceError.storeFailure) {
            try failing.restore(validated)
        }
        let accounts = try destination.mainContext.fetch(FetchDescriptor<CashAccount>())
        #expect(accounts.single?.id == oldID)
        #expect(defaults.string(forKey: AppTheme.storageKey) == "original")
    }

    @Test("A failed recovery write prevents every restore mutation")
    func recoveryFailureStopsRestore() throws {
        enum SyntheticFailure: Error { case write }

        let source = try makeContainer()
        _ = try insertCompleteFixture(in: source.mainContext)
        let incoming = try service(container: source, defaults: makeDefaults()).makeDocument(
            exportedAt: instant,
            appVersion: "1.0",
            flavour: .dev
        )
        let validated = try MonMonBackupValidator.validate(incoming, expectedFlavour: .dev)
        let destination = try makeContainer()
        let oldID = UUID()
        destination.mainContext.insert(
            CashAccount(
                id: oldID,
                name: "Old",
                kind: .normal,
                openingBalance: 1,
                currencyCode: VNDCurrency.code,
                createdAt: instant
            )
        )
        try destination.mainContext.save()
        let failing = MonMonBackupService(
            container: destination,
            defaults: makeDefaults(),
            recoveryURL: temporaryRecoveryURL(),
            writeRecovery: { _, _ in throw SyntheticFailure.write }
        )

        #expect(throws: MonMonBackupServiceError.recoveryFailure) {
            try failing.restore(validated)
        }
        #expect(
            try destination.mainContext.fetch(FetchDescriptor<CashAccount>()).single?.id == oldID)
    }

    @Test("Restoring a legacy account clears any previous Credit limit")
    func legacyAccountDefaultsCreditLimitToZero() throws {
        let id = UUID()
        var payload = MonMonBackupPayload.empty
        payload.accounts = [
            MonMonBackupPayload.AccountRecord(
                id: MonMonBackupScalar.uuid(id),
                name: "Legacy Bank",
                kind: "bank",
                openingBalance: "1000",
                currencyCode: VNDCurrency.code,
                createdAt: MonMonBackupScalar.date(instant)
            )
        ]
        let incoming = try MonMonBackupDocument.make(
            payload: payload,
            exportedAt: instant,
            appVersion: "1.0",
            flavour: .dev
        )
        let validated = try MonMonBackupValidator.validate(incoming, expectedFlavour: .dev)

        let destination = try makeContainer()
        destination.mainContext.insert(
            CashAccount(
                id: id,
                name: "Existing Credit",
                kind: .credit,
                openingBalance: -500,
                creditLimit: 10_000,
                currencyCode: VNDCurrency.code,
                createdAt: instant
            )
        )
        try destination.mainContext.save()
        let recoveryURL = temporaryRecoveryURL()
        defer { try? FileManager.default.removeItem(at: recoveryURL) }

        _ = try service(
            container: destination,
            defaults: makeDefaults(),
            recoveryURL: recoveryURL
        ).restore(validated)

        let restored = try #require(
            destination.mainContext.fetch(FetchDescriptor<CashAccount>()).single
        )
        #expect(restored.kind == .normal)
        #expect(restored.creditLimit == 0)
    }

    private func makeContainer() throws -> ModelContainer {
        try ModelContainer(
            for: Schema(MonMonSchema.models),
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    private func makeDefaults() -> UserDefaults {
        let suiteName = "monmon.backup.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName) ?? .standard
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }

    private func service(
        container: ModelContainer,
        defaults: UserDefaults,
        recoveryURL: URL? = nil
    ) -> MonMonBackupService {
        MonMonBackupService(
            container: container,
            defaults: defaults,
            recoveryURL: recoveryURL ?? temporaryRecoveryURL()
        )
    }

    private func temporaryRecoveryURL() -> URL {
        FileManager.default.temporaryDirectory
            .appending(path: "monmon-recovery-\(UUID().uuidString).json")
    }

    private func insertCompleteFixture(in context: ModelContext) throws -> FixtureIDs {
        let bankID = UUID()
        let walletID = UUID()
        let categoryID = UUID()
        let ruleID = UUID()
        let instrumentID = UUID()
        let depositID = UUID()
        let holdingID = UUID()
        let debtID = UUID()

        context.insert(
            CashAccount(
                id: bankID,
                name: "Bank",
                kind: .credit,
                openingBalance: 10_000,
                creditLimit: 20_000,
                currencyCode: VNDCurrency.code,
                createdAt: instant
            )
        )
        context.insert(
            CashAccount(
                id: walletID,
                name: "Wallet",
                kind: .normal,
                openingBalance: 500,
                currencyCode: VNDCurrency.code,
                createdAt: instant.addingTimeInterval(1)
            )
        )
        context.insert(
            TransactionCategory(
                id: categoryID,
                name: "Food",
                kind: .expense,
                symbolName: "fork.knife",
                colorName: "orange",
                createdAt: instant
            )
        )
        context.insert(
            RecurringRule(
                id: ruleID,
                kind: .expense,
                amount: 100,
                note: "Recurring",
                accountID: bankID,
                categoryID: categoryID,
                currencyCode: VNDCurrency.code,
                frequency: .monthly,
                interval: 1,
                anchorDate: instant,
                endDate: nil,
                isPaused: false,
                lastGeneratedAt: nil,
                createdAt: instant
            )
        )
        context.insert(
            FundInstrument(
                id: instrumentID,
                symbol: "TEST",
                name: "Synthetic Fund",
                kind: .fund,
                currentPricePerUnit: 20,
                askPricePerUnit: 0,
                priceAsOf: instant,
                priceSource: FundQuoteSource.manual.rawValue,
                priceFetchedAt: nil,
                autoQuoteEnabled: false,
                currencyCode: VNDCurrency.code,
                createdAt: instant
            )
        )
        context.insert(
            SavingsDeposit(
                id: depositID,
                name: "Deposit",
                principal: 1_000,
                annualInterestRate: 5,
                termMonths: 12,
                openedAt: instant,
                currencyCode: VNDCurrency.code,
                createdAt: instant,
                sourceAccountID: bankID
            )
        )
        context.insert(
            FundHolding(
                id: holdingID,
                instrumentID: instrumentID,
                units: 10,
                averageCostPerUnit: 15,
                createdAt: instant,
                sourceAccountID: bankID,
                purchasedAt: instant
            )
        )
        context.insert(
            Debt(
                id: debtID,
                counterparty: "Synthetic Person",
                direction: .borrowed,
                principal: 2_000,
                annualInterestRate: 0,
                openedAt: instant,
                dueDate: nil,
                accountID: bankID,
                note: "",
                currencyCode: VNDCurrency.code,
                createdAt: instant
            )
        )
        context.insert(
            MoneyTransaction(
                id: UUID(),
                kind: .expense,
                amount: 100,
                occurredAt: instant,
                note: "Synthetic",
                accountID: bankID,
                categoryID: categoryID,
                sourceRuleID: ruleID,
                currencyCode: VNDCurrency.code,
                createdAt: instant,
                sourceImportID: importedSource
            )
        )
        context.insert(
            PendingTransactionCapture(
                id: UUID(),
                rawText: "pending",
                kind: .expense,
                amount: nil,
                occurredAt: instant,
                note: "",
                accountID: bankID,
                categoryID: categoryID,
                issueCodes: TransactionCaptureIssue.missingAmount.rawValue,
                createdAt: instant
            )
        )
        context.insert(
            AccountTransfer(
                id: UUID(),
                amount: 100,
                occurredAt: instant,
                note: "Move",
                sourceAccountID: bankID,
                destinationAccountID: walletID,
                currencyCode: VNDCurrency.code,
                createdAt: instant,
                sourceAccountImportID: importedSource,
                destinationAccountImportID: nil
            )
        )
        context.insert(
            SavingsWithdrawal(
                id: UUID(),
                depositID: depositID,
                principal: 100,
                amountReceived: 105,
                destinationAccountID: bankID,
                withdrawnAt: instant,
                note: "Partial",
                currencyCode: VNDCurrency.code,
                createdAt: instant
            )
        )
        context.insert(
            FundSale(
                id: UUID(),
                holdingID: holdingID,
                units: 1,
                pricePerUnit: 25,
                proceedsAccountID: bankID,
                soldAt: instant,
                note: "Partial",
                currencyCode: VNDCurrency.code,
                createdAt: instant
            )
        )
        context.insert(
            DebtPayment(
                id: UUID(),
                debtID: debtID,
                amount: 200,
                occurredAt: instant,
                accountID: bankID,
                note: "Payment",
                currencyCode: VNDCurrency.code,
                createdAt: instant
            )
        )
        try context.save()
        return FixtureIDs(bankID: bankID, walletID: walletID, categoryID: categoryID)
    }
}

private struct FixtureIDs {
    let bankID: UUID
    let walletID: UUID
    let categoryID: UUID
}

extension Array {
    fileprivate var single: Element? {
        count == 1 ? first : nil
    }
}

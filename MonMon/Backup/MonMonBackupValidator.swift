import Foundation

enum MonMonBackupFlavour: String, Codable, Equatable, Sendable {
    case dev
    case prod

    static var current: MonMonBackupFlavour {
        #if DEBUG
            .dev
        #else
            .prod
        #endif
    }
}

enum MonMonBackupValidationError: Error, Equatable, Sendable {
    case fileTooLarge
    case invalidDocument
    case unsupportedFormat
    case unsupportedVersion
    case wrongFlavour
    case checksumMismatch
    case invalidPayload
    case duplicateIdentifier
    case invalidReference
}

enum MonMonBackupWarning: Equatable, Sendable {
    case danglingOptionalReferences
    case stalePreferences
}

struct MonMonBackupCounts: Equatable, Sendable {
    var accounts: Int
    var savingsDeposits: Int
    var savingsWithdrawals: Int
    var fundInstruments: Int
    var fundHoldings: Int
    var fundSales: Int
    var categories: Int
    var transactions: Int
    var pendingCaptures: Int
    var transfers: Int
    var debts: Int
    var debtPayments: Int
    var recurringRules: Int

    init(payload: MonMonBackupPayload) {
        accounts = payload.accounts.count
        savingsDeposits = payload.savingsDeposits.count
        savingsWithdrawals = payload.savingsWithdrawals.count
        fundInstruments = payload.fundInstruments.count
        fundHoldings = payload.fundHoldings.count
        fundSales = payload.fundSales.count
        categories = payload.categories.count
        transactions = payload.transactions.count
        pendingCaptures = payload.pendingCaptures.count
        transfers = payload.transfers.count
        debts = payload.debts.count
        debtPayments = payload.debtPayments.count
        recurringRules = payload.recurringRules.count
    }
}

struct MonMonBackupPreview: Equatable, Sendable {
    var exportedAt: Date
    var appVersion: String
    var flavour: MonMonBackupFlavour
    var counts: MonMonBackupCounts

    var incomingRecordCount: Int {
        counts.accounts + counts.savingsDeposits + counts.savingsWithdrawals
            + counts.fundInstruments + counts.fundHoldings + counts.fundSales
            + counts.categories + counts.transactions + counts.pendingCaptures
            + counts.transfers + counts.debts + counts.debtPayments + counts.recurringRules
    }
}

struct ValidatedMonMonBackup: Equatable, Sendable {
    var document: MonMonBackupDocument
    var payload: MonMonBackupPayload
    var preview: MonMonBackupPreview
    var warnings: [MonMonBackupWarning]
}

enum MonMonBackupValidator {
    static let maximumByteCount = 100 * 1_024 * 1_024

    static func decodeAndValidate(
        _ data: Data,
        expectedFlavour: MonMonBackupFlavour = .current,
        maximumByteCount: Int = maximumByteCount
    ) throws -> ValidatedMonMonBackup {
        guard data.count <= maximumByteCount else {
            throw MonMonBackupValidationError.fileTooLarge
        }

        let document: MonMonBackupDocument
        do {
            document = try MonMonBackupCodec.decode(data)
        } catch {
            throw MonMonBackupValidationError.invalidDocument
        }
        return try validate(document, expectedFlavour: expectedFlavour)
    }

    static func validate(
        _ document: MonMonBackupDocument,
        expectedFlavour: MonMonBackupFlavour = .current
    ) throws -> ValidatedMonMonBackup {
        guard document.format == MonMonBackupDocument.currentFormat else {
            throw MonMonBackupValidationError.unsupportedFormat
        }
        guard document.formatVersion == MonMonBackupDocument.currentVersion else {
            throw MonMonBackupValidationError.unsupportedVersion
        }
        guard document.flavour == expectedFlavour else {
            throw MonMonBackupValidationError.wrongFlavour
        }
        guard !document.appVersion.isEmpty,
            let exportedAt = try? MonMonBackupScalar.parseDate(document.exportedAt)
        else {
            throw MonMonBackupValidationError.invalidPayload
        }

        let actualChecksum: String
        do {
            actualChecksum = try MonMonBackupCodec.payloadSHA256(document.payload)
        } catch {
            throw MonMonBackupValidationError.invalidPayload
        }
        guard document.payloadSHA256 == actualChecksum else {
            throw MonMonBackupValidationError.checksumMismatch
        }
        guard document.payload == document.payload.sorted() else {
            throw MonMonBackupValidationError.invalidPayload
        }

        var checker = PayloadChecker(payload: document.payload)
        let payload: MonMonBackupPayload
        do {
            try checker.validate()
            payload = try checker.sanitizedPayload()
        } catch let error as MonMonBackupValidationError {
            throw error
        } catch {
            throw MonMonBackupValidationError.invalidPayload
        }
        return ValidatedMonMonBackup(
            document: document,
            payload: payload,
            preview: MonMonBackupPreview(
                exportedAt: exportedAt,
                appVersion: document.appVersion,
                flavour: document.flavour,
                counts: MonMonBackupCounts(payload: payload)
            ),
            warnings: checker.warnings
        )
    }
}

enum MonMonBackupFileReader {
    static func read(
        _ url: URL,
        maximumByteCount: Int = MonMonBackupValidator.maximumByteCount
    ) throws -> Data {
        guard maximumByteCount >= 0, maximumByteCount < Int.max else {
            throw MonMonBackupValidationError.fileTooLarge
        }
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var data = Data()
        while data.count <= maximumByteCount {
            let remaining = maximumByteCount + 1 - data.count
            guard let chunk = try handle.read(upToCount: min(64 * 1_024, remaining)),
                !chunk.isEmpty
            else {
                return data
            }
            data.append(chunk)
        }
        throw MonMonBackupValidationError.fileTooLarge
    }
}

private struct PayloadChecker {
    let payload: MonMonBackupPayload
    private(set) var warnings: [MonMonBackupWarning] = []
    private var hasDanglingOptionalReference = false

    fileprivate init(payload: MonMonBackupPayload) {
        self.payload = payload
    }

    mutating func validate() throws {
        try validateUniqueRecords(payload.accounts) { record in
            try scalarIDAndDate(record.id, record.createdAt)
            try require(CashAccountKind(rawValue: record.kind) != nil)
            _ = try MonMonBackupScalar.parseDecimal(record.openingBalance)
            try currency(record.currencyCode)
        }
        try validateUniqueRecords(payload.categories) { record in
            try scalarIDAndDate(record.id, record.createdAt)
            try require(TransactionKind(rawValue: record.kind) != nil)
            try require(
                !record.name.isEmpty && !record.symbolName.isEmpty && !record.colorName.isEmpty)
        }
        try validateUniqueRecords(payload.fundInstruments) { record in
            try scalarIDAndDate(record.id, record.createdAt)
            try require(FundInstrumentKind(rawValue: record.kind) != nil)
            try nonnegative(record.currentPricePerUnit)
            try nonnegative(record.askPricePerUnit)
            try date(record.priceAsOf)
            try optionalDate(record.priceFetchedAt)
            try currency(record.currencyCode)
        }
        try validateUniqueRecords(payload.savingsDeposits) { record in
            try scalarIDAndDate(record.id, record.createdAt)
            try positive(record.principal)
            try nonnegative(record.annualInterestRate)
            try require(record.termMonths > 0)
            try date(record.openedAt)
            try optionalUUID(record.sourceAccountID)
            try currency(record.currencyCode)
        }
        try validateUniqueRecords(payload.fundHoldings) { record in
            try scalarIDAndDate(record.id, record.createdAt)
            try optionalUUID(record.instrumentID)
            try positive(record.units)
            try nonnegative(record.averageCostPerUnit)
            try optionalUUID(record.sourceAccountID)
            try optionalDate(record.purchasedAt)
        }
        try validateUniqueRecords(payload.debts) { record in
            try scalarIDAndDate(record.id, record.createdAt)
            try require(!record.counterparty.isEmpty)
            try require(DebtDirection(rawValue: record.direction) != nil)
            try positive(record.principal)
            try nonnegative(record.annualInterestRate)
            try date(record.openedAt)
            try optionalDate(record.dueDate)
            try optionalUUID(record.accountID)
            try currency(record.currencyCode)
        }
        try validateUniqueRecords(payload.recurringRules) { record in
            try scalarIDAndDate(record.id, record.createdAt)
            try require(TransactionKind(rawValue: record.kind) != nil)
            try positive(record.amount)
            try uuid(record.accountID)
            try optionalUUID(record.categoryID)
            try currency(record.currencyCode)
            try require(RecurrenceFrequency(rawValue: record.frequency) != nil)
            try require(record.interval > 0)
            try date(record.anchorDate)
            try optionalDate(record.endDate)
            try optionalDate(record.lastGeneratedAt)
        }
        try validateUniqueRecords(payload.transactions) { record in
            try scalarIDAndDate(record.id, record.createdAt)
            try require(TransactionKind(rawValue: record.kind) != nil)
            try positive(record.amount)
            try date(record.occurredAt)
            try uuid(record.accountID)
            try optionalUUID(record.categoryID)
            try optionalUUID(record.sourceRuleID)
            try currency(record.currencyCode)
            try importHash(record.sourceImportID)
        }
        try validateUniqueRecords(payload.pendingCaptures) { record in
            try scalarIDAndDate(record.id, record.createdAt)
            try require(TransactionKind(rawValue: record.kind) != nil)
            if let amount = record.amount { try positive(amount) }
            try date(record.occurredAt)
            try optionalUUID(record.accountID)
            try optionalUUID(record.categoryID)
            try issueCodes(record.issueCodes)
        }
        try validateUniqueRecords(payload.transfers) { record in
            try scalarIDAndDate(record.id, record.createdAt)
            try positive(record.amount)
            try date(record.occurredAt)
            try uuid(record.sourceAccountID)
            try uuid(record.destinationAccountID)
            try require(record.sourceAccountID != record.destinationAccountID)
            try currency(record.currencyCode)
            try importHash(record.sourceAccountImportID)
            try importHash(record.destinationAccountImportID)
        }
        try validateUniqueRecords(payload.savingsWithdrawals) { record in
            try scalarIDAndDate(record.id, record.createdAt)
            try optionalUUID(record.depositID)
            try positive(record.principal)
            try positive(record.amountReceived)
            try uuid(record.destinationAccountID)
            try date(record.withdrawnAt)
            try currency(record.currencyCode)
        }
        try validateUniqueRecords(payload.fundSales) { record in
            try scalarIDAndDate(record.id, record.createdAt)
            try optionalUUID(record.holdingID)
            try positive(record.units)
            try nonnegative(record.pricePerUnit)
            try uuid(record.proceedsAccountID)
            try date(record.soldAt)
            try currency(record.currencyCode)
        }
        try validateUniqueRecords(payload.debtPayments) { record in
            try scalarIDAndDate(record.id, record.createdAt)
            try optionalUUID(record.debtID)
            try positive(record.amount)
            try date(record.occurredAt)
            try uuid(record.accountID)
            try currency(record.currencyCode)
        }

        try validateReferencesAndKinds()
        try validateAggregateLimits()
        if hasDanglingOptionalReference {
            warnings.append(.danglingOptionalReferences)
        }
    }

    mutating func sanitizedPayload() throws -> MonMonBackupPayload {
        var result = payload
        let accountIDs = Set(payload.accounts.map(\.id))
        let categoryKinds = Dictionary(
            uniqueKeysWithValues: payload.categories.map { ($0.id, $0.kind) })
        var stalePreference = false

        try validatePreferenceEnum(result.preferences.theme, as: AppTheme.self)
        try validatePreferenceEnum(result.preferences.language, as: AppLanguage.self)
        result.preferences.defaultAccountID = sanitizedPreferenceID(
            result.preferences.defaultAccountID,
            validIDs: accountIDs,
            stale: &stalePreference
        )
        result.preferences.defaultExpenseCategoryID = sanitizedCategoryPreference(
            result.preferences.defaultExpenseCategoryID,
            expectedKind: TransactionKind.expense.rawValue,
            categoryKinds: categoryKinds,
            stale: &stalePreference
        )
        result.preferences.defaultIncomeCategoryID = sanitizedCategoryPreference(
            result.preferences.defaultIncomeCategoryID,
            expectedKind: TransactionKind.income.rawValue,
            categoryKinds: categoryKinds,
            stale: &stalePreference
        )

        var mappings: [String: String] = [:]
        for (key, value) in result.preferences.statementAccountMappings {
            try mappingKey(key)
            try uuid(value)
            if accountIDs.contains(value) {
                mappings[key] = value
            } else {
                stalePreference = true
            }
        }
        result.preferences.statementAccountMappings = mappings
        if stalePreference {
            warnings.append(.stalePreferences)
        }
        return result
    }

    private mutating func validateReferencesAndKinds() throws {
        let accounts = Set(payload.accounts.map(\.id))
        let categories = Dictionary(
            uniqueKeysWithValues: payload.categories.map { ($0.id, $0.kind) })
        let instruments = Set(payload.fundInstruments.map(\.id))
        let deposits = Set(payload.savingsDeposits.map(\.id))
        let holdings = Set(payload.fundHoldings.map(\.id))
        let debts = Set(payload.debts.map(\.id))
        let rules = Set(payload.recurringRules.map(\.id))

        for record in payload.savingsDeposits {
            optionalReference(record.sourceAccountID, validIDs: accounts)
        }
        for record in payload.savingsWithdrawals {
            try requiredReference(record.destinationAccountID, validIDs: accounts)
            optionalReference(record.depositID, validIDs: deposits)
        }
        for record in payload.fundHoldings {
            optionalReference(record.instrumentID, validIDs: instruments)
            optionalReference(record.sourceAccountID, validIDs: accounts)
        }
        for record in payload.fundSales {
            try requiredReference(record.proceedsAccountID, validIDs: accounts)
            optionalReference(record.holdingID, validIDs: holdings)
        }
        for record in payload.transactions {
            try requiredReference(record.accountID, validIDs: accounts)
            try categoryReference(record.categoryID, kind: record.kind, categories: categories)
            optionalReference(record.sourceRuleID, validIDs: rules)
        }
        for record in payload.pendingCaptures {
            optionalReference(record.accountID, validIDs: accounts)
            try categoryReference(record.categoryID, kind: record.kind, categories: categories)
        }
        for record in payload.transfers {
            try requiredReference(record.sourceAccountID, validIDs: accounts)
            try requiredReference(record.destinationAccountID, validIDs: accounts)
        }
        for record in payload.debts {
            optionalReference(record.accountID, validIDs: accounts)
        }
        for record in payload.debtPayments {
            try requiredReference(record.accountID, validIDs: accounts)
            optionalReference(record.debtID, validIDs: debts)
        }
        for record in payload.recurringRules {
            try requiredReference(record.accountID, validIDs: accounts)
            try categoryReference(record.categoryID, kind: record.kind, categories: categories)
        }
    }

    private func validateAggregateLimits() throws {
        let holdingUnits = try Dictionary(
            uniqueKeysWithValues: payload.fundHoldings.map {
                ($0.id, try MonMonBackupScalar.parseDecimal($0.units))
            }
        )
        var soldUnits: [String: Decimal] = [:]
        for sale in payload.fundSales {
            guard let holdingID = sale.holdingID, holdingUnits[holdingID] != nil else { continue }
            soldUnits[holdingID, default: .zero] += try MonMonBackupScalar.parseDecimal(sale.units)
        }
        for (holdingID, units) in soldUnits {
            guard let available = holdingUnits[holdingID], units <= available else {
                throw MonMonBackupValidationError.invalidPayload
            }
        }

        let depositPrincipal = try Dictionary(
            uniqueKeysWithValues: payload.savingsDeposits.map {
                ($0.id, try MonMonBackupScalar.parseDecimal($0.principal))
            }
        )
        var withdrawnPrincipal: [String: Decimal] = [:]
        for withdrawal in payload.savingsWithdrawals {
            guard let depositID = withdrawal.depositID, depositPrincipal[depositID] != nil else {
                continue
            }
            withdrawnPrincipal[depositID, default: .zero] += try MonMonBackupScalar.parseDecimal(
                withdrawal.principal
            )
        }
        for (depositID, principal) in withdrawnPrincipal {
            guard let available = depositPrincipal[depositID], principal <= available else {
                throw MonMonBackupValidationError.invalidPayload
            }
        }
    }

    private mutating func categoryReference(
        _ id: String?,
        kind: String,
        categories: [String: String]
    ) throws {
        guard let id else { return }
        guard let categoryKind = categories[id] else {
            hasDanglingOptionalReference = true
            return
        }
        try require(categoryKind == kind)
    }

    private mutating func optionalReference(_ id: String?, validIDs: Set<String>) {
        if let id, !validIDs.contains(id) {
            hasDanglingOptionalReference = true
        }
    }

    private func requiredReference(_ id: String, validIDs: Set<String>) throws {
        guard validIDs.contains(id) else {
            throw MonMonBackupValidationError.invalidReference
        }
    }

    private func sanitizedPreferenceID(
        _ value: String?,
        validIDs: Set<String>,
        stale: inout Bool
    ) -> String? {
        guard let value else { return nil }
        guard validIDs.contains(value) else {
            stale = true
            return nil
        }
        return value
    }

    private func sanitizedCategoryPreference(
        _ value: String?,
        expectedKind: String,
        categoryKinds: [String: String],
        stale: inout Bool
    ) -> String? {
        guard let value else { return nil }
        guard categoryKinds[value] == expectedKind else {
            stale = true
            return nil
        }
        return value
    }

    private func validatePreferenceEnum<T>(_ value: String?, as _: T.Type) throws
    where T: RawRepresentable, T.RawValue == String {
        if let value {
            try require(T(rawValue: value) != nil)
        }
    }

    private func mappingKey(_ value: String) throws {
        let pieces = value.split(separator: "|", omittingEmptySubsequences: false)
        try require(pieces.count == 2)
        try require(BankStatementBank(rawValue: String(pieces[0])) != nil)
        let suffix = pieces[1]
        try require(suffix.utf8.count == 4 && suffix.utf8.allSatisfy { (48...57).contains($0) })
    }

    private func validateUniqueRecords<T>(
        _ records: [T],
        validate: (T) throws -> Void
    ) throws where T: BackupIdentified {
        var ids = Set<String>()
        for record in records {
            guard ids.insert(record.id).inserted else {
                throw MonMonBackupValidationError.duplicateIdentifier
            }
            try validate(record)
        }
    }

    private func scalarIDAndDate(_ id: String, _ createdAt: String) throws {
        try uuid(id)
        try date(createdAt)
    }

    private func uuid(_ value: String) throws {
        _ = try MonMonBackupScalar.parseUUID(value)
    }

    private func optionalUUID(_ value: String?) throws {
        if let value { try uuid(value) }
    }

    private func date(_ value: String) throws {
        _ = try MonMonBackupScalar.parseDate(value)
    }

    private func optionalDate(_ value: String?) throws {
        if let value { try date(value) }
    }

    private func positive(_ value: String) throws {
        let parsed = try MonMonBackupScalar.parseDecimal(value)
        try require(parsed > .zero)
    }

    private func nonnegative(_ value: String) throws {
        let parsed = try MonMonBackupScalar.parseDecimal(value)
        try require(parsed >= .zero)
    }

    private func currency(_ value: String) throws {
        try require(value == VNDCurrency.code)
    }

    private func importHash(_ value: String?) throws {
        if let value {
            try require(ImportSourceID(rawValue: value) != nil)
        }
    }

    private func issueCodes(_ value: String) throws {
        guard !value.isEmpty else { return }
        let codes = value.split(separator: ",").map(String.init)
        try require(codes == codes.sorted() && Set(codes).count == codes.count)
        try require(codes.allSatisfy { TransactionCaptureIssue(rawValue: $0) != nil })
    }

    private func require(_ condition: @autoclosure () -> Bool) throws {
        guard condition() else {
            throw MonMonBackupValidationError.invalidPayload
        }
    }
}

private protocol BackupIdentified {
    var id: String { get }
}

extension MonMonBackupPayload.AccountRecord: BackupIdentified {}
extension MonMonBackupPayload.SavingsDepositRecord: BackupIdentified {}
extension MonMonBackupPayload.SavingsWithdrawalRecord: BackupIdentified {}
extension MonMonBackupPayload.FundInstrumentRecord: BackupIdentified {}
extension MonMonBackupPayload.FundHoldingRecord: BackupIdentified {}
extension MonMonBackupPayload.FundSaleRecord: BackupIdentified {}
extension MonMonBackupPayload.CategoryRecord: BackupIdentified {}
extension MonMonBackupPayload.TransactionRecord: BackupIdentified {}
extension MonMonBackupPayload.PendingCaptureRecord: BackupIdentified {}
extension MonMonBackupPayload.TransferRecord: BackupIdentified {}
extension MonMonBackupPayload.DebtRecord: BackupIdentified {}
extension MonMonBackupPayload.DebtPaymentRecord: BackupIdentified {}
extension MonMonBackupPayload.RecurringRuleRecord: BackupIdentified {}

import CryptoKit
import Foundation

enum MonMonBackupScalarError: Error, Equatable, Sendable {
    case invalidUUID
    case invalidDecimal
    case invalidDate
}

enum MonMonBackupScalar {
    private static let posixLocale = Locale(identifier: "en_US_POSIX")

    static func uuid(_ value: UUID) -> String {
        value.uuidString.lowercased()
    }

    static func parseUUID(_ value: String) throws -> UUID {
        guard let parsed = UUID(uuidString: value), uuid(parsed) == value else {
            throw MonMonBackupScalarError.invalidUUID
        }
        return parsed
    }

    static func decimal(_ value: Decimal) -> String {
        if value == .zero {
            return "0"
        }
        return NSDecimalNumber(decimal: value).stringValue
    }

    static func parseDecimal(_ value: String) throws -> Decimal {
        guard let parsed = Decimal(string: value, locale: posixLocale), !parsed.isNaN,
            decimal(parsed) == value
        else {
            throw MonMonBackupScalarError.invalidDecimal
        }
        return parsed
    }

    static func date(_ value: Date) -> String {
        dateFormatter().string(from: value)
    }

    static func parseDate(_ value: String) throws -> Date {
        guard let parsed = dateFormatter().date(from: value), date(parsed) == value else {
            throw MonMonBackupScalarError.invalidDate
        }
        return parsed
    }

    private static func dateFormatter() -> ISO8601DateFormatter {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }
}

struct MonMonBackupDocument: Codable, Equatable, Sendable {
    static let currentFormat = "monmon-backup"
    static let currentVersion = 1

    var format: String
    var formatVersion: Int
    var exportedAt: String
    var appVersion: String
    var flavour: MonMonBackupFlavour
    var payload: MonMonBackupPayload
    var payloadSHA256: String

    static func make(
        payload: MonMonBackupPayload,
        exportedAt: Date,
        appVersion: String,
        flavour: MonMonBackupFlavour
    ) throws -> MonMonBackupDocument {
        let sortedPayload = payload.sorted()
        return MonMonBackupDocument(
            format: currentFormat,
            formatVersion: currentVersion,
            exportedAt: MonMonBackupScalar.date(exportedAt),
            appVersion: appVersion,
            flavour: flavour,
            payload: sortedPayload,
            payloadSHA256: try MonMonBackupCodec.payloadSHA256(sortedPayload)
        )
    }
}

enum MonMonBackupCodec {
    static func encode(_ document: MonMonBackupDocument) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(document)
    }

    static func decode(_ data: Data) throws -> MonMonBackupDocument {
        try JSONDecoder().decode(MonMonBackupDocument.self, from: data)
    }

    static func payloadSHA256(_ payload: MonMonBackupPayload) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        let digest = SHA256.hash(data: try encoder.encode(payload))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}

private protocol MonMonBackupRecord {
    var id: String { get }
    var createdAt: String { get }
}

private extension Array where Element: MonMonBackupRecord {
    func backupSorted() -> [Element] {
        sorted {
            if $0.createdAt == $1.createdAt {
                return $0.id < $1.id
            }
            return $0.createdAt < $1.createdAt
        }
    }
}

struct MonMonBackupPayload: Codable, Equatable, Sendable {
    var accounts: [AccountRecord]
    var savingsDeposits: [SavingsDepositRecord]
    var savingsWithdrawals: [SavingsWithdrawalRecord]
    var fundInstruments: [FundInstrumentRecord]
    var fundHoldings: [FundHoldingRecord]
    var fundSales: [FundSaleRecord]
    var budgetJars: [BudgetJarRecord]
    var goals: [GoalRecord]
    var tripWorkspaces: [TripWorkspaceRecord]
    var categories: [CategoryRecord]
    var transactions: [TransactionRecord]
    var pendingCaptures: [PendingCaptureRecord]
    var transfers: [TransferRecord]
    var debts: [DebtRecord]
    var debtPayments: [DebtPaymentRecord]
    var recurringRules: [RecurringRuleRecord]
    var preferences: Preferences
    private var includesBudgetJars: Bool
    private var includesGoals: Bool
    private var includesTripWorkspaces: Bool

    private enum CodingKeys: String, CodingKey {
        case accounts
        case savingsDeposits
        case savingsWithdrawals
        case fundInstruments
        case fundHoldings
        case fundSales
        case budgetJars
        case goals
        case tripWorkspaces
        case categories
        case transactions
        case pendingCaptures
        case transfers
        case debts
        case debtPayments
        case recurringRules
        case preferences
    }

    static let empty = MonMonBackupPayload(
        accounts: [],
        savingsDeposits: [],
        savingsWithdrawals: [],
        fundInstruments: [],
        fundHoldings: [],
        fundSales: [],
        budgetJars: [],
        goals: [],
        tripWorkspaces: [],
        categories: [],
        transactions: [],
        pendingCaptures: [],
        transfers: [],
        debts: [],
        debtPayments: [],
        recurringRules: [],
        preferences: .empty
    )

    init(
        accounts: [AccountRecord],
        savingsDeposits: [SavingsDepositRecord],
        savingsWithdrawals: [SavingsWithdrawalRecord],
        fundInstruments: [FundInstrumentRecord],
        fundHoldings: [FundHoldingRecord],
        fundSales: [FundSaleRecord],
        budgetJars: [BudgetJarRecord],
        goals: [GoalRecord],
        tripWorkspaces: [TripWorkspaceRecord] = [],
        categories: [CategoryRecord],
        transactions: [TransactionRecord],
        pendingCaptures: [PendingCaptureRecord],
        transfers: [TransferRecord],
        debts: [DebtRecord],
        debtPayments: [DebtPaymentRecord],
        recurringRules: [RecurringRuleRecord],
        preferences: Preferences
    ) {
        self.accounts = accounts
        self.savingsDeposits = savingsDeposits
        self.savingsWithdrawals = savingsWithdrawals
        self.fundInstruments = fundInstruments
        self.fundHoldings = fundHoldings
        self.fundSales = fundSales
        self.budgetJars = budgetJars
        self.goals = goals
        self.tripWorkspaces = tripWorkspaces
        self.categories = categories
        self.transactions = transactions
        self.pendingCaptures = pendingCaptures
        self.transfers = transfers
        self.debts = debts
        self.debtPayments = debtPayments
        self.recurringRules = recurringRules
        self.preferences = preferences
        includesBudgetJars = true
        includesGoals = true
        includesTripWorkspaces = true
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        accounts = try container.decode([AccountRecord].self, forKey: .accounts)
        savingsDeposits = try container.decode(
            [SavingsDepositRecord].self,
            forKey: .savingsDeposits
        )
        savingsWithdrawals = try container.decode(
            [SavingsWithdrawalRecord].self,
            forKey: .savingsWithdrawals
        )
        fundInstruments = try container.decode(
            [FundInstrumentRecord].self,
            forKey: .fundInstruments
        )
        fundHoldings = try container.decode([FundHoldingRecord].self, forKey: .fundHoldings)
        fundSales = try container.decode([FundSaleRecord].self, forKey: .fundSales)
        includesBudgetJars = container.contains(.budgetJars)
        budgetJars =
            try container.decodeIfPresent([BudgetJarRecord].self, forKey: .budgetJars) ?? []
        includesGoals = container.contains(.goals)
        goals = try container.decodeIfPresent([GoalRecord].self, forKey: .goals) ?? []
        includesTripWorkspaces = container.contains(.tripWorkspaces)
        tripWorkspaces =
            try container.decodeIfPresent([TripWorkspaceRecord].self, forKey: .tripWorkspaces)
            ?? []
        categories = try container.decode([CategoryRecord].self, forKey: .categories)
        transactions = try container.decode([TransactionRecord].self, forKey: .transactions)
        pendingCaptures = try container.decode(
            [PendingCaptureRecord].self,
            forKey: .pendingCaptures
        )
        transfers = try container.decode([TransferRecord].self, forKey: .transfers)
        debts = try container.decode([DebtRecord].self, forKey: .debts)
        debtPayments = try container.decode([DebtPaymentRecord].self, forKey: .debtPayments)
        recurringRules = try container.decode([RecurringRuleRecord].self, forKey: .recurringRules)
        preferences = try container.decode(Preferences.self, forKey: .preferences)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(accounts, forKey: .accounts)
        try container.encode(savingsDeposits, forKey: .savingsDeposits)
        try container.encode(savingsWithdrawals, forKey: .savingsWithdrawals)
        try container.encode(fundInstruments, forKey: .fundInstruments)
        try container.encode(fundHoldings, forKey: .fundHoldings)
        try container.encode(fundSales, forKey: .fundSales)
        if includesBudgetJars {
            try container.encode(budgetJars, forKey: .budgetJars)
        }
        if includesGoals {
            try container.encode(goals, forKey: .goals)
        }
        if includesTripWorkspaces {
            try container.encode(tripWorkspaces, forKey: .tripWorkspaces)
        }
        try container.encode(categories, forKey: .categories)
        try container.encode(transactions, forKey: .transactions)
        try container.encode(pendingCaptures, forKey: .pendingCaptures)
        try container.encode(transfers, forKey: .transfers)
        try container.encode(debts, forKey: .debts)
        try container.encode(debtPayments, forKey: .debtPayments)
        try container.encode(recurringRules, forKey: .recurringRules)
        try container.encode(preferences, forKey: .preferences)
    }

    func sorted() -> MonMonBackupPayload {
        var result = self
        result.accounts = accounts.backupSorted()
        result.savingsDeposits = savingsDeposits.backupSorted()
        result.savingsWithdrawals = savingsWithdrawals.backupSorted()
        result.fundInstruments = fundInstruments.backupSorted()
        result.fundHoldings = fundHoldings.backupSorted()
        result.fundSales = fundSales.backupSorted()
        result.budgetJars = budgetJars.backupSorted()
        result.goals = goals.backupSorted()
        result.tripWorkspaces = tripWorkspaces.backupSorted()
        result.categories = categories.backupSorted()
        result.transactions = transactions.backupSorted()
        result.pendingCaptures = pendingCaptures.backupSorted()
        result.transfers = transfers.backupSorted()
        result.debts = debts.backupSorted()
        result.debtPayments = debtPayments.backupSorted()
        result.recurringRules = recurringRules.backupSorted()
        return result
    }

    var recordCount: Int {
        accounts.count + savingsDeposits.count + savingsWithdrawals.count
            + fundInstruments.count + fundHoldings.count + fundSales.count
            + budgetJars.count + goals.count + tripWorkspaces.count + categories.count
            + transactions.count
            + pendingCaptures.count
            + transfers.count + debts.count + debtPayments.count + recurringRules.count
    }

    struct Preferences: Codable, Equatable, Sendable {
        var theme: String?
        var language: String?
        var defaultAccountID: String?
        var defaultExpenseCategoryID: String?
        var defaultIncomeCategoryID: String?
        var statementAccountMappings: [String: String]

        static let empty = Preferences(
            theme: nil,
            language: nil,
            defaultAccountID: nil,
            defaultExpenseCategoryID: nil,
            defaultIncomeCategoryID: nil,
            statementAccountMappings: [:]
        )
    }

    struct AccountRecord: Codable, Equatable, Sendable, MonMonBackupRecord {
        var id: String
        var name: String
        var kind: String
        var openingBalance: String
        var creditLimit: String? = nil
        var currencyCode: String
        var createdAt: String
    }

    struct SavingsDepositRecord: Codable, Equatable, Sendable, MonMonBackupRecord {
        var id: String
        var name: String
        var principal: String
        var annualInterestRate: String
        var termMonths: Int
        var openedAt: String
        var currencyCode: String
        var createdAt: String
        var sourceAccountID: String?
    }

    struct SavingsWithdrawalRecord: Codable, Equatable, Sendable, MonMonBackupRecord {
        var id: String
        var depositID: String?
        var principal: String
        var amountReceived: String
        var destinationAccountID: String
        var withdrawnAt: String
        var note: String
        var currencyCode: String
        var createdAt: String
    }

    struct FundInstrumentRecord: Codable, Equatable, Sendable, MonMonBackupRecord {
        var id: String
        var symbol: String
        var name: String
        var kind: String
        var currentPricePerUnit: String
        var askPricePerUnit: String
        var priceAsOf: String
        var priceSource: String
        var priceFetchedAt: String?
        var autoQuoteEnabled: Bool
        /// Absent in backups written before instruments carried a logo, and in
        /// every instrument added by hand. Decodes as `nil` either way.
        var logoURL: String?
        /// How the provider names this instrument, when that is not the ticker.
        /// Absent in backups written before coins existed, and in everything a
        /// ticker already identifies. Decodes as `nil` either way, which is why
        /// this needs no version bump.
        var providerID: String?
        var currencyCode: String
        var createdAt: String
    }

    struct FundHoldingRecord: Codable, Equatable, Sendable, MonMonBackupRecord {
        var id: String
        var instrumentID: String?
        var units: String
        var averageCostPerUnit: String
        var sourceAccountID: String?
        var createdAt: String
        var purchasedAt: String?
    }

    struct FundSaleRecord: Codable, Equatable, Sendable, MonMonBackupRecord {
        var id: String
        var holdingID: String?
        var units: String
        var pricePerUnit: String
        var proceedsAccountID: String
        var soldAt: String
        var note: String
        var currencyCode: String
        var createdAt: String
    }

    struct CategoryRecord: Codable, Equatable, Sendable, MonMonBackupRecord {
        var id: String
        var name: String
        var kind: String
        var symbolName: String
        var colorName: String
        var createdAt: String
        var budgetJarID: String? = nil
    }

    struct BudgetJarRecord: Codable, Equatable, Sendable, MonMonBackupRecord {
        var id: String
        var name: String
        var allocationPercent: String
        var role: String
        var symbolName: String
        var colorName: String
        var createdAt: String
    }

    struct GoalRecord: Codable, Equatable, Sendable, MonMonBackupRecord {
        var id: String
        var name: String
        var targetAmount: String
        var earmarkedAmount: String
        var targetDate: String
        var monthlyContribution: String
        var fundingJarID: String
        var symbolName: String
        var colorName: String
        var createdAt: String
        var contributions: [GoalContributionRecord]? = nil
        var archivedAt: String? = nil
    }

    struct GoalContributionRecord: Codable, Equatable, Sendable {
        var id: String
        var amount: String
        var occurredAt: String
    }

    struct TripWorkspaceRecord: Codable, Equatable, Sendable, MonMonBackupRecord {
        var id: String
        var sourceGoalID: String?
        var name: String
        var budgetAmount: String
        var fundingJarID: String?
        var symbolName: String
        var colorName: String
        var status: String
        var startedAt: String
        var completedAt: String?
        var createdAt: String
    }

    struct TransactionRecord: Codable, Equatable, Sendable, MonMonBackupRecord {
        var id: String
        var kind: String
        var amount: String
        var occurredAt: String
        var note: String
        var accountID: String
        var categoryID: String?
        var sourceRuleID: String?
        var currencyCode: String
        var createdAt: String
        var sourceImportID: String?
        var incomeAllocationSnapshot: String? = nil
        var tripWorkspaceID: String? = nil
        var budgetJarOverrideID: String? = nil
    }

    struct PendingCaptureRecord: Codable, Equatable, Sendable, MonMonBackupRecord {
        var id: String
        var rawText: String
        var kind: String
        var amount: String?
        var occurredAt: String
        var note: String
        var accountID: String?
        var categoryID: String?
        var issueCodes: String
        var createdAt: String
    }

    struct TransferRecord: Codable, Equatable, Sendable, MonMonBackupRecord {
        var id: String
        var amount: String
        var occurredAt: String
        var note: String
        var sourceAccountID: String
        var destinationAccountID: String
        var currencyCode: String
        var createdAt: String
        var sourceAccountImportID: String?
        var destinationAccountImportID: String?
    }

    struct DebtRecord: Codable, Equatable, Sendable, MonMonBackupRecord {
        var id: String
        var counterparty: String
        var direction: String
        var principal: String
        var annualInterestRate: String
        var openedAt: String
        var dueDate: String?
        var accountID: String?
        var note: String
        var currencyCode: String
        var createdAt: String
    }

    struct DebtPaymentRecord: Codable, Equatable, Sendable, MonMonBackupRecord {
        var id: String
        var debtID: String?
        var amount: String
        var occurredAt: String
        var accountID: String
        var note: String
        var currencyCode: String
        var createdAt: String
    }

    struct RecurringRuleRecord: Codable, Equatable, Sendable, MonMonBackupRecord {
        var id: String
        var kind: String
        var amount: String
        var note: String
        var accountID: String
        var categoryID: String?
        var currencyCode: String
        var frequency: String
        var interval: Int
        var anchorDate: String
        var endDate: String?
        var isPaused: Bool
        var lastGeneratedAt: String?
        var createdAt: String
    }
}

import Foundation
import SwiftData

enum MonMonBackupServiceError: Error, Equatable, Sendable {
    case outputTooLarge
    case recoveryFailure
    case storeFailure
    case invalidSnapshot
}

private extension MonMonBackupService {
    func apply(_ payload: MonMonBackupPayload, in context: ModelContext) throws {
        try reconcile(
            current: context.fetch(FetchDescriptor<CashAccount>()),
            records: payload.accounts,
            in: context,
            modelID: \CashAccount.id,
            createdAt: \CashAccount.createdAt,
            recordID: { try MonMonBackupScalar.parseUUID($0.id) },
            make: makeAccount,
            update: updateAccount
        )
        try reconcile(
            current: context.fetch(FetchDescriptor<BudgetJar>()),
            records: payload.budgetJars,
            in: context,
            modelID: \BudgetJar.id,
            createdAt: \BudgetJar.createdAt,
            recordID: { try MonMonBackupScalar.parseUUID($0.id) },
            make: makeBudgetJar,
            update: updateBudgetJar
        )
        try reconcile(
            current: context.fetch(FetchDescriptor<FinancialGoal>()),
            records: payload.goals,
            in: context,
            modelID: \FinancialGoal.id,
            createdAt: \FinancialGoal.createdAt,
            recordID: { try MonMonBackupScalar.parseUUID($0.id) },
            make: makeGoal,
            update: updateGoal
        )
        try reconcile(
            current: context.fetch(FetchDescriptor<TransactionCategory>()),
            records: payload.categories,
            in: context,
            modelID: \TransactionCategory.id,
            createdAt: \TransactionCategory.createdAt,
            recordID: { try MonMonBackupScalar.parseUUID($0.id) },
            make: makeCategory,
            update: updateCategory
        )
        try reconcile(
            current: context.fetch(FetchDescriptor<FundInstrument>()),
            records: payload.fundInstruments,
            in: context,
            modelID: \FundInstrument.id,
            createdAt: \FundInstrument.createdAt,
            recordID: { try MonMonBackupScalar.parseUUID($0.id) },
            make: makeFundInstrument,
            update: updateFundInstrument
        )
        try reconcile(
            current: context.fetch(FetchDescriptor<SavingsDeposit>()),
            records: payload.savingsDeposits,
            in: context,
            modelID: \SavingsDeposit.id,
            createdAt: \SavingsDeposit.createdAt,
            recordID: { try MonMonBackupScalar.parseUUID($0.id) },
            make: makeSavingsDeposit,
            update: updateSavingsDeposit
        )
        try reconcile(
            current: context.fetch(FetchDescriptor<FundHolding>()),
            records: payload.fundHoldings,
            in: context,
            modelID: \FundHolding.id,
            createdAt: \FundHolding.createdAt,
            recordID: { try MonMonBackupScalar.parseUUID($0.id) },
            make: makeFundHolding,
            update: updateFundHolding
        )
        try reconcile(
            current: context.fetch(FetchDescriptor<Debt>()),
            records: payload.debts,
            in: context,
            modelID: \Debt.id,
            createdAt: \Debt.createdAt,
            recordID: { try MonMonBackupScalar.parseUUID($0.id) },
            make: makeDebt,
            update: updateDebt
        )
        try reconcile(
            current: context.fetch(FetchDescriptor<RecurringRule>()),
            records: payload.recurringRules,
            in: context,
            modelID: \RecurringRule.id,
            createdAt: \RecurringRule.createdAt,
            recordID: { try MonMonBackupScalar.parseUUID($0.id) },
            make: makeRecurringRule,
            update: updateRecurringRule
        )
        try reconcile(
            current: context.fetch(FetchDescriptor<MoneyTransaction>()),
            records: payload.transactions,
            in: context,
            modelID: \MoneyTransaction.id,
            createdAt: \MoneyTransaction.createdAt,
            recordID: { try MonMonBackupScalar.parseUUID($0.id) },
            make: makeTransaction,
            update: updateTransaction
        )
        try reconcile(
            current: context.fetch(FetchDescriptor<PendingTransactionCapture>()),
            records: payload.pendingCaptures,
            in: context,
            modelID: \PendingTransactionCapture.id,
            createdAt: \PendingTransactionCapture.createdAt,
            recordID: { try MonMonBackupScalar.parseUUID($0.id) },
            make: makePendingCapture,
            update: updatePendingCapture
        )
        try reconcile(
            current: context.fetch(FetchDescriptor<AccountTransfer>()),
            records: payload.transfers,
            in: context,
            modelID: \AccountTransfer.id,
            createdAt: \AccountTransfer.createdAt,
            recordID: { try MonMonBackupScalar.parseUUID($0.id) },
            make: makeTransfer,
            update: updateTransfer
        )
        try reconcile(
            current: context.fetch(FetchDescriptor<SavingsWithdrawal>()),
            records: payload.savingsWithdrawals,
            in: context,
            modelID: \SavingsWithdrawal.id,
            createdAt: \SavingsWithdrawal.createdAt,
            recordID: { try MonMonBackupScalar.parseUUID($0.id) },
            make: makeSavingsWithdrawal,
            update: updateSavingsWithdrawal
        )
        try reconcile(
            current: context.fetch(FetchDescriptor<FundSale>()),
            records: payload.fundSales,
            in: context,
            modelID: \FundSale.id,
            createdAt: \FundSale.createdAt,
            recordID: { try MonMonBackupScalar.parseUUID($0.id) },
            make: makeFundSale,
            update: updateFundSale
        )
        try reconcile(
            current: context.fetch(FetchDescriptor<DebtPayment>()),
            records: payload.debtPayments,
            in: context,
            modelID: \DebtPayment.id,
            createdAt: \DebtPayment.createdAt,
            recordID: { try MonMonBackupScalar.parseUUID($0.id) },
            make: makeDebtPayment,
            update: updateDebtPayment
        )

        if payload.budgetJars.isEmpty {
            BudgetJarSeed.seedIfNeeded(in: context, saveChanges: false)
        }
    }

    func reconcile<Model, Record>(
        current: [Model],
        records: [Record],
        in context: ModelContext,
        modelID: KeyPath<Model, UUID>,
        createdAt: KeyPath<Model, Date>,
        recordID: (Record) throws -> UUID,
        make: (Record) throws -> Model,
        update: (Model, Record) throws -> Void
    ) throws where Model: PersistentModel {
        var grouped = Dictionary(grouping: current) { $0[keyPath: modelID] }
        for record in records {
            let id = try recordID(record)
            if let matches = grouped.removeValue(forKey: id), !matches.isEmpty {
                let sortedMatches = matches.sorted {
                    if $0[keyPath: createdAt] == $1[keyPath: createdAt] {
                        return String(describing: $0.persistentModelID)
                            < String(describing: $1.persistentModelID)
                    }
                    return $0[keyPath: createdAt] < $1[keyPath: createdAt]
                }
                guard let survivor = sortedMatches.first else {
                    throw MonMonBackupServiceError.invalidSnapshot
                }
                try update(survivor, record)
                for duplicate in sortedMatches.dropFirst() {
                    context.delete(duplicate)
                }
            } else {
                context.insert(try make(record))
            }
        }
        for obsolete in grouped.values.joined() {
            context.delete(obsolete)
        }
    }

    func makeAccount(_ record: MonMonBackupPayload.AccountRecord) throws -> CashAccount {
        let model = CashAccount(
            id: try MonMonBackupScalar.parseUUID(record.id),
            name: record.name,
            kind: try enumValue(record.kind),
            openingBalance: try MonMonBackupScalar.parseDecimal(record.openingBalance),
            creditLimit: try record.creditLimit.map(MonMonBackupScalar.parseDecimal) ?? .zero,
            currencyCode: record.currencyCode,
            createdAt: try MonMonBackupScalar.parseDate(record.createdAt)
        )
        return model
    }

    func updateAccount(_ model: CashAccount, _ record: MonMonBackupPayload.AccountRecord) throws {
        model.id = try MonMonBackupScalar.parseUUID(record.id)
        model.name = record.name
        model.kind = try enumValue(record.kind)
        model.openingBalance = try MonMonBackupScalar.parseDecimal(record.openingBalance)
        model.creditLimit =
            try record.creditLimit.map(MonMonBackupScalar.parseDecimal) ?? .zero
        model.currencyCode = record.currencyCode
        model.createdAt = try MonMonBackupScalar.parseDate(record.createdAt)
    }

    func makeCategory(_ record: MonMonBackupPayload.CategoryRecord) throws
        -> TransactionCategory
    {
        TransactionCategory(
            id: try MonMonBackupScalar.parseUUID(record.id),
            name: record.name,
            kind: try enumValue(record.kind),
            symbolName: record.symbolName,
            colorName: record.colorName,
            createdAt: try MonMonBackupScalar.parseDate(record.createdAt),
            budgetJarID: try optionalUUID(record.budgetJarID)
        )
    }

    func updateCategory(
        _ model: TransactionCategory,
        _ record: MonMonBackupPayload.CategoryRecord
    ) throws {
        model.id = try MonMonBackupScalar.parseUUID(record.id)
        model.name = record.name
        model.kind = try enumValue(record.kind)
        model.symbolName = record.symbolName
        model.colorName = record.colorName
        model.createdAt = try MonMonBackupScalar.parseDate(record.createdAt)
        model.budgetJarID = try optionalUUID(record.budgetJarID)
    }

    func makeBudgetJar(_ record: MonMonBackupPayload.BudgetJarRecord) throws -> BudgetJar {
        BudgetJar(
            id: try MonMonBackupScalar.parseUUID(record.id),
            name: record.name,
            allocationPercent: try MonMonBackupScalar.parseDecimal(record.allocationPercent),
            role: try enumValue(record.role),
            symbolName: record.symbolName,
            colorName: record.colorName,
            createdAt: try MonMonBackupScalar.parseDate(record.createdAt)
        )
    }

    func updateBudgetJar(
        _ model: BudgetJar,
        _ record: MonMonBackupPayload.BudgetJarRecord
    ) throws {
        model.id = try MonMonBackupScalar.parseUUID(record.id)
        model.name = record.name
        model.allocationPercent = try MonMonBackupScalar.parseDecimal(record.allocationPercent)
        model.role = try enumValue(record.role)
        model.symbolName = record.symbolName
        model.colorName = record.colorName
        model.createdAt = try MonMonBackupScalar.parseDate(record.createdAt)
    }

    func makeGoal(_ record: MonMonBackupPayload.GoalRecord) throws -> FinancialGoal {
        FinancialGoal(
            id: try MonMonBackupScalar.parseUUID(record.id),
            name: record.name,
            kind: try enumValue(record.kind),
            targetAmount: try MonMonBackupScalar.parseDecimal(record.targetAmount),
            earmarkedAmount: try MonMonBackupScalar.parseDecimal(record.earmarkedAmount),
            targetDate: try MonMonBackupScalar.parseDate(record.targetDate),
            monthlyContribution: try MonMonBackupScalar.parseDecimal(record.monthlyContribution),
            fundingJarID: try MonMonBackupScalar.parseUUID(record.fundingJarID),
            symbolName: record.symbolName,
            colorName: record.colorName,
            createdAt: try MonMonBackupScalar.parseDate(record.createdAt)
        )
    }

    func updateGoal(_ model: FinancialGoal, _ record: MonMonBackupPayload.GoalRecord) throws {
        model.id = try MonMonBackupScalar.parseUUID(record.id)
        model.name = record.name
        model.kind = try enumValue(record.kind)
        model.targetAmount = try MonMonBackupScalar.parseDecimal(record.targetAmount)
        model.earmarkedAmount = try MonMonBackupScalar.parseDecimal(record.earmarkedAmount)
        model.targetDate = try MonMonBackupScalar.parseDate(record.targetDate)
        model.monthlyContribution = try MonMonBackupScalar.parseDecimal(
            record.monthlyContribution)
        model.fundingJarID = try MonMonBackupScalar.parseUUID(record.fundingJarID)
        model.symbolName = record.symbolName
        model.colorName = record.colorName
        model.createdAt = try MonMonBackupScalar.parseDate(record.createdAt)
    }

    func makeFundInstrument(
        _ record: MonMonBackupPayload.FundInstrumentRecord
    ) throws -> FundInstrument {
        FundInstrument(
            id: try MonMonBackupScalar.parseUUID(record.id),
            symbol: record.symbol,
            name: record.name,
            kind: try enumValue(record.kind),
            currentPricePerUnit: try MonMonBackupScalar.parseDecimal(record.currentPricePerUnit),
            askPricePerUnit: try MonMonBackupScalar.parseDecimal(record.askPricePerUnit),
            priceAsOf: try MonMonBackupScalar.parseDate(record.priceAsOf),
            priceSource: record.priceSource,
            priceFetchedAt: try optionalDate(record.priceFetchedAt),
            autoQuoteEnabled: record.autoQuoteEnabled,
            logoURL: record.logoURL,
            currencyCode: record.currencyCode,
            createdAt: try MonMonBackupScalar.parseDate(record.createdAt)
        )
    }

    func updateFundInstrument(
        _ model: FundInstrument,
        _ record: MonMonBackupPayload.FundInstrumentRecord
    ) throws {
        model.id = try MonMonBackupScalar.parseUUID(record.id)
        model.symbol = record.symbol
        model.name = record.name
        model.kind = try enumValue(record.kind)
        model.currentPricePerUnit = try MonMonBackupScalar.parseDecimal(record.currentPricePerUnit)
        model.askPricePerUnit = try MonMonBackupScalar.parseDecimal(record.askPricePerUnit)
        model.priceAsOf = try MonMonBackupScalar.parseDate(record.priceAsOf)
        model.priceSource = record.priceSource
        model.priceFetchedAt = try optionalDate(record.priceFetchedAt)
        model.autoQuoteEnabled = record.autoQuoteEnabled
        model.logoURL = record.logoURL
        model.currencyCode = record.currencyCode
        model.createdAt = try MonMonBackupScalar.parseDate(record.createdAt)
    }

    func makeSavingsDeposit(
        _ record: MonMonBackupPayload.SavingsDepositRecord
    ) throws -> SavingsDeposit {
        SavingsDeposit(
            id: try MonMonBackupScalar.parseUUID(record.id),
            name: record.name,
            principal: try MonMonBackupScalar.parseDecimal(record.principal),
            annualInterestRate: try MonMonBackupScalar.parseDecimal(record.annualInterestRate),
            termMonths: record.termMonths,
            openedAt: try MonMonBackupScalar.parseDate(record.openedAt),
            currencyCode: record.currencyCode,
            createdAt: try MonMonBackupScalar.parseDate(record.createdAt),
            sourceAccountID: try optionalUUID(record.sourceAccountID)
        )
    }

    func updateSavingsDeposit(
        _ model: SavingsDeposit,
        _ record: MonMonBackupPayload.SavingsDepositRecord
    ) throws {
        model.id = try MonMonBackupScalar.parseUUID(record.id)
        model.name = record.name
        model.principal = try MonMonBackupScalar.parseDecimal(record.principal)
        model.annualInterestRate = try MonMonBackupScalar.parseDecimal(record.annualInterestRate)
        model.termMonths = record.termMonths
        model.openedAt = try MonMonBackupScalar.parseDate(record.openedAt)
        model.currencyCode = record.currencyCode
        model.createdAt = try MonMonBackupScalar.parseDate(record.createdAt)
        model.sourceAccountID = try optionalUUID(record.sourceAccountID)
    }

    func makeFundHolding(_ record: MonMonBackupPayload.FundHoldingRecord) throws -> FundHolding {
        FundHolding(
            id: try MonMonBackupScalar.parseUUID(record.id),
            instrumentID: try optionalUUID(record.instrumentID),
            units: try MonMonBackupScalar.parseDecimal(record.units),
            averageCostPerUnit: try MonMonBackupScalar.parseDecimal(record.averageCostPerUnit),
            createdAt: try MonMonBackupScalar.parseDate(record.createdAt),
            sourceAccountID: try optionalUUID(record.sourceAccountID),
            purchasedAt: try optionalDate(record.purchasedAt)
        )
    }

    func updateFundHolding(
        _ model: FundHolding,
        _ record: MonMonBackupPayload.FundHoldingRecord
    ) throws {
        model.id = try MonMonBackupScalar.parseUUID(record.id)
        model.instrumentID = try optionalUUID(record.instrumentID)
        model.units = try MonMonBackupScalar.parseDecimal(record.units)
        model.averageCostPerUnit = try MonMonBackupScalar.parseDecimal(record.averageCostPerUnit)
        model.sourceAccountID = try optionalUUID(record.sourceAccountID)
        model.createdAt = try MonMonBackupScalar.parseDate(record.createdAt)
        model.purchasedAt = try optionalDate(record.purchasedAt)
    }

    func makeDebt(_ record: MonMonBackupPayload.DebtRecord) throws -> Debt {
        Debt(
            id: try MonMonBackupScalar.parseUUID(record.id),
            counterparty: record.counterparty,
            direction: try enumValue(record.direction),
            principal: try MonMonBackupScalar.parseDecimal(record.principal),
            annualInterestRate: try MonMonBackupScalar.parseDecimal(record.annualInterestRate),
            openedAt: try MonMonBackupScalar.parseDate(record.openedAt),
            dueDate: try optionalDate(record.dueDate),
            accountID: try optionalUUID(record.accountID),
            note: record.note,
            currencyCode: record.currencyCode,
            createdAt: try MonMonBackupScalar.parseDate(record.createdAt)
        )
    }

    func updateDebt(_ model: Debt, _ record: MonMonBackupPayload.DebtRecord) throws {
        model.id = try MonMonBackupScalar.parseUUID(record.id)
        model.counterparty = record.counterparty
        model.direction = try enumValue(record.direction)
        model.principal = try MonMonBackupScalar.parseDecimal(record.principal)
        model.annualInterestRate = try MonMonBackupScalar.parseDecimal(record.annualInterestRate)
        model.openedAt = try MonMonBackupScalar.parseDate(record.openedAt)
        model.dueDate = try optionalDate(record.dueDate)
        model.accountID = try optionalUUID(record.accountID)
        model.note = record.note
        model.currencyCode = record.currencyCode
        model.createdAt = try MonMonBackupScalar.parseDate(record.createdAt)
    }

    func makeRecurringRule(
        _ record: MonMonBackupPayload.RecurringRuleRecord
    ) throws -> RecurringRule {
        RecurringRule(
            id: try MonMonBackupScalar.parseUUID(record.id),
            kind: try enumValue(record.kind),
            amount: try MonMonBackupScalar.parseDecimal(record.amount),
            note: record.note,
            accountID: try MonMonBackupScalar.parseUUID(record.accountID),
            categoryID: try optionalUUID(record.categoryID),
            currencyCode: record.currencyCode,
            frequency: try enumValue(record.frequency),
            interval: record.interval,
            anchorDate: try MonMonBackupScalar.parseDate(record.anchorDate),
            endDate: try optionalDate(record.endDate),
            isPaused: record.isPaused,
            lastGeneratedAt: try optionalDate(record.lastGeneratedAt),
            createdAt: try MonMonBackupScalar.parseDate(record.createdAt)
        )
    }

    func updateRecurringRule(
        _ model: RecurringRule,
        _ record: MonMonBackupPayload.RecurringRuleRecord
    ) throws {
        model.id = try MonMonBackupScalar.parseUUID(record.id)
        model.kind = try enumValue(record.kind)
        model.amount = try MonMonBackupScalar.parseDecimal(record.amount)
        model.note = record.note
        model.accountID = try MonMonBackupScalar.parseUUID(record.accountID)
        model.categoryID = try optionalUUID(record.categoryID)
        model.currencyCode = record.currencyCode
        model.frequency = try enumValue(record.frequency)
        model.interval = record.interval
        model.anchorDate = try MonMonBackupScalar.parseDate(record.anchorDate)
        model.endDate = try optionalDate(record.endDate)
        model.isPaused = record.isPaused
        model.lastGeneratedAt = try optionalDate(record.lastGeneratedAt)
        model.createdAt = try MonMonBackupScalar.parseDate(record.createdAt)
    }

    func makeTransaction(
        _ record: MonMonBackupPayload.TransactionRecord
    ) throws -> MoneyTransaction {
        MoneyTransaction(
            id: try MonMonBackupScalar.parseUUID(record.id),
            kind: try enumValue(record.kind),
            amount: try MonMonBackupScalar.parseDecimal(record.amount),
            occurredAt: try MonMonBackupScalar.parseDate(record.occurredAt),
            note: record.note,
            accountID: try MonMonBackupScalar.parseUUID(record.accountID),
            categoryID: try optionalUUID(record.categoryID),
            sourceRuleID: try optionalUUID(record.sourceRuleID),
            currencyCode: record.currencyCode,
            createdAt: try MonMonBackupScalar.parseDate(record.createdAt),
            sourceImportID: record.sourceImportID,
            incomeAllocationSnapshot: record.incomeAllocationSnapshot
        )
    }

    func updateTransaction(
        _ model: MoneyTransaction,
        _ record: MonMonBackupPayload.TransactionRecord
    ) throws {
        model.id = try MonMonBackupScalar.parseUUID(record.id)
        model.kind = try enumValue(record.kind)
        model.amount = try MonMonBackupScalar.parseDecimal(record.amount)
        model.occurredAt = try MonMonBackupScalar.parseDate(record.occurredAt)
        model.note = record.note
        model.accountID = try MonMonBackupScalar.parseUUID(record.accountID)
        model.categoryID = try optionalUUID(record.categoryID)
        model.sourceRuleID = try optionalUUID(record.sourceRuleID)
        model.currencyCode = record.currencyCode
        model.createdAt = try MonMonBackupScalar.parseDate(record.createdAt)
        model.sourceImportID = record.sourceImportID
        model.incomeAllocationSnapshot = record.incomeAllocationSnapshot
    }

    func makePendingCapture(
        _ record: MonMonBackupPayload.PendingCaptureRecord
    ) throws -> PendingTransactionCapture {
        PendingTransactionCapture(
            id: try MonMonBackupScalar.parseUUID(record.id),
            rawText: record.rawText,
            kind: try enumValue(record.kind),
            amount: try optionalDecimal(record.amount),
            occurredAt: try MonMonBackupScalar.parseDate(record.occurredAt),
            note: record.note,
            accountID: try optionalUUID(record.accountID),
            categoryID: try optionalUUID(record.categoryID),
            issueCodes: record.issueCodes,
            createdAt: try MonMonBackupScalar.parseDate(record.createdAt)
        )
    }

    func updatePendingCapture(
        _ model: PendingTransactionCapture,
        _ record: MonMonBackupPayload.PendingCaptureRecord
    ) throws {
        model.id = try MonMonBackupScalar.parseUUID(record.id)
        model.rawText = record.rawText
        model.kind = try enumValue(record.kind)
        model.amount = try optionalDecimal(record.amount)
        model.occurredAt = try MonMonBackupScalar.parseDate(record.occurredAt)
        model.note = record.note
        model.accountID = try optionalUUID(record.accountID)
        model.categoryID = try optionalUUID(record.categoryID)
        model.issueCodes = record.issueCodes
        model.createdAt = try MonMonBackupScalar.parseDate(record.createdAt)
    }

    func makeTransfer(_ record: MonMonBackupPayload.TransferRecord) throws -> AccountTransfer {
        AccountTransfer(
            id: try MonMonBackupScalar.parseUUID(record.id),
            amount: try MonMonBackupScalar.parseDecimal(record.amount),
            occurredAt: try MonMonBackupScalar.parseDate(record.occurredAt),
            note: record.note,
            sourceAccountID: try MonMonBackupScalar.parseUUID(record.sourceAccountID),
            destinationAccountID: try MonMonBackupScalar.parseUUID(record.destinationAccountID),
            currencyCode: record.currencyCode,
            createdAt: try MonMonBackupScalar.parseDate(record.createdAt),
            sourceAccountImportID: record.sourceAccountImportID,
            destinationAccountImportID: record.destinationAccountImportID
        )
    }

    func updateTransfer(
        _ model: AccountTransfer,
        _ record: MonMonBackupPayload.TransferRecord
    ) throws {
        model.id = try MonMonBackupScalar.parseUUID(record.id)
        model.amount = try MonMonBackupScalar.parseDecimal(record.amount)
        model.occurredAt = try MonMonBackupScalar.parseDate(record.occurredAt)
        model.note = record.note
        model.sourceAccountID = try MonMonBackupScalar.parseUUID(record.sourceAccountID)
        model.destinationAccountID = try MonMonBackupScalar.parseUUID(record.destinationAccountID)
        model.currencyCode = record.currencyCode
        model.createdAt = try MonMonBackupScalar.parseDate(record.createdAt)
        model.sourceAccountImportID = record.sourceAccountImportID
        model.destinationAccountImportID = record.destinationAccountImportID
    }

    func makeSavingsWithdrawal(
        _ record: MonMonBackupPayload.SavingsWithdrawalRecord
    ) throws -> SavingsWithdrawal {
        SavingsWithdrawal(
            id: try MonMonBackupScalar.parseUUID(record.id),
            depositID: try optionalUUID(record.depositID),
            principal: try MonMonBackupScalar.parseDecimal(record.principal),
            amountReceived: try MonMonBackupScalar.parseDecimal(record.amountReceived),
            destinationAccountID: try MonMonBackupScalar.parseUUID(record.destinationAccountID),
            withdrawnAt: try MonMonBackupScalar.parseDate(record.withdrawnAt),
            note: record.note,
            currencyCode: record.currencyCode,
            createdAt: try MonMonBackupScalar.parseDate(record.createdAt)
        )
    }

    func updateSavingsWithdrawal(
        _ model: SavingsWithdrawal,
        _ record: MonMonBackupPayload.SavingsWithdrawalRecord
    ) throws {
        model.id = try MonMonBackupScalar.parseUUID(record.id)
        model.depositID = try optionalUUID(record.depositID)
        model.principal = try MonMonBackupScalar.parseDecimal(record.principal)
        model.amountReceived = try MonMonBackupScalar.parseDecimal(record.amountReceived)
        model.destinationAccountID = try MonMonBackupScalar.parseUUID(record.destinationAccountID)
        model.withdrawnAt = try MonMonBackupScalar.parseDate(record.withdrawnAt)
        model.note = record.note
        model.currencyCode = record.currencyCode
        model.createdAt = try MonMonBackupScalar.parseDate(record.createdAt)
    }

    func makeFundSale(_ record: MonMonBackupPayload.FundSaleRecord) throws -> FundSale {
        FundSale(
            id: try MonMonBackupScalar.parseUUID(record.id),
            holdingID: try optionalUUID(record.holdingID),
            units: try MonMonBackupScalar.parseDecimal(record.units),
            pricePerUnit: try MonMonBackupScalar.parseDecimal(record.pricePerUnit),
            proceedsAccountID: try MonMonBackupScalar.parseUUID(record.proceedsAccountID),
            soldAt: try MonMonBackupScalar.parseDate(record.soldAt),
            note: record.note,
            currencyCode: record.currencyCode,
            createdAt: try MonMonBackupScalar.parseDate(record.createdAt)
        )
    }

    func updateFundSale(
        _ model: FundSale,
        _ record: MonMonBackupPayload.FundSaleRecord
    ) throws {
        model.id = try MonMonBackupScalar.parseUUID(record.id)
        model.holdingID = try optionalUUID(record.holdingID)
        model.units = try MonMonBackupScalar.parseDecimal(record.units)
        model.pricePerUnit = try MonMonBackupScalar.parseDecimal(record.pricePerUnit)
        model.proceedsAccountID = try MonMonBackupScalar.parseUUID(record.proceedsAccountID)
        model.soldAt = try MonMonBackupScalar.parseDate(record.soldAt)
        model.note = record.note
        model.currencyCode = record.currencyCode
        model.createdAt = try MonMonBackupScalar.parseDate(record.createdAt)
    }

    func makeDebtPayment(
        _ record: MonMonBackupPayload.DebtPaymentRecord
    ) throws -> DebtPayment {
        DebtPayment(
            id: try MonMonBackupScalar.parseUUID(record.id),
            debtID: try optionalUUID(record.debtID),
            amount: try MonMonBackupScalar.parseDecimal(record.amount),
            occurredAt: try MonMonBackupScalar.parseDate(record.occurredAt),
            accountID: try MonMonBackupScalar.parseUUID(record.accountID),
            note: record.note,
            currencyCode: record.currencyCode,
            createdAt: try MonMonBackupScalar.parseDate(record.createdAt)
        )
    }

    func updateDebtPayment(
        _ model: DebtPayment,
        _ record: MonMonBackupPayload.DebtPaymentRecord
    ) throws {
        model.id = try MonMonBackupScalar.parseUUID(record.id)
        model.debtID = try optionalUUID(record.debtID)
        model.amount = try MonMonBackupScalar.parseDecimal(record.amount)
        model.occurredAt = try MonMonBackupScalar.parseDate(record.occurredAt)
        model.accountID = try MonMonBackupScalar.parseUUID(record.accountID)
        model.note = record.note
        model.currencyCode = record.currencyCode
        model.createdAt = try MonMonBackupScalar.parseDate(record.createdAt)
    }

    func apply(_ preferences: MonMonBackupPayload.Preferences, to defaults: UserDefaults) {
        set(preferences.theme, forKey: AppTheme.storageKey, in: defaults)
        set(preferences.language, forKey: AppLanguage.storageKey, in: defaults)
        setPreferenceUUID(
            preferences.defaultAccountID,
            forKey: TransactionDefaults.accountStorageKey,
            in: defaults
        )
        setPreferenceUUID(
            preferences.defaultExpenseCategoryID,
            forKey: TransactionDefaults.categoryStorageKey,
            in: defaults
        )
        setPreferenceUUID(
            preferences.defaultIncomeCategoryID,
            forKey: TransactionDefaults.incomeCategoryStorageKey,
            in: defaults
        )
        let mappings = preferences.statementAccountMappings.compactMapValues {
            UUID(uuidString: $0)?.uuidString
        }
        defaults.set(mappings, forKey: StatementAccountMapping.storageKey)
    }

    func set(_ value: String?, forKey key: String, in defaults: UserDefaults) {
        if let value {
            defaults.set(value, forKey: key)
        } else {
            defaults.removeObject(forKey: key)
        }
    }

    func setPreferenceUUID(_ value: String?, forKey key: String, in defaults: UserDefaults) {
        set(value.flatMap(UUID.init(uuidString:))?.uuidString, forKey: key, in: defaults)
    }

    func optionalUUID(_ value: String?) throws -> UUID? {
        try value.map(MonMonBackupScalar.parseUUID)
    }

    func optionalDate(_ value: String?) throws -> Date? {
        try value.map(MonMonBackupScalar.parseDate)
    }

    func optionalDecimal(_ value: String?) throws -> Decimal? {
        try value.map(MonMonBackupScalar.parseDecimal)
    }

    func enumValue<T>(_ rawValue: String) throws -> T
    where T: RawRepresentable, T.RawValue == String {
        guard let value = T(rawValue: rawValue) else {
            throw MonMonBackupServiceError.invalidSnapshot
        }
        return value
    }
}

struct MonMonBackupRestoreReport: Equatable, Sendable {
    var restoredRecordCount: Int
}

@MainActor
struct MonMonBackupService {
    typealias Save = @MainActor (ModelContext) throws -> Void
    typealias RecoveryWriter = @MainActor (Data, URL) throws -> Void

    private let container: ModelContainer
    private let defaults: UserDefaults
    let recoveryURL: URL
    private let save: Save
    private let writeRecovery: RecoveryWriter

    init(
        container: ModelContainer,
        defaults: UserDefaults = .standard,
        recoveryURL: URL = MonMonBackupService.defaultRecoveryURL,
        save: @escaping Save = { try $0.save() },
        writeRecovery: @escaping RecoveryWriter = MonMonBackupService.writeRecoveryData
    ) {
        self.container = container
        self.defaults = defaults
        self.recoveryURL = recoveryURL
        self.save = save
        self.writeRecovery = writeRecovery
    }

    static var defaultRecoveryURL: URL {
        let base =
            FileManager.default.urls(
                for: .applicationSupportDirectory,
                in: .userDomainMask
            ).first ?? FileManager.default.temporaryDirectory
        return
            base
            .appending(path: "MonMon", directoryHint: .isDirectory)
            .appending(path: "restore-recovery.json", directoryHint: .notDirectory)
    }

    func makeDocument(
        exportedAt: Date = .now,
        appVersion: String = MonMonBackupService.currentAppVersion,
        flavour: MonMonBackupFlavour = .current
    ) throws -> MonMonBackupDocument {
        let payload = try snapshotPayload()
        let document = try MonMonBackupDocument.make(
            payload: payload,
            exportedAt: exportedAt,
            appVersion: appVersion,
            flavour: flavour
        )
        let validated = try MonMonBackupValidator.validate(document, expectedFlavour: flavour)
        guard validated.payload != payload else {
            return document
        }
        return try MonMonBackupDocument.make(
            payload: validated.payload,
            exportedAt: exportedAt,
            appVersion: appVersion,
            flavour: flavour
        )
    }

    func exportData(
        exportedAt: Date = .now,
        appVersion: String = MonMonBackupService.currentAppVersion,
        flavour: MonMonBackupFlavour = .current
    ) throws -> Data {
        let data = try MonMonBackupCodec.encode(
            makeDocument(exportedAt: exportedAt, appVersion: appVersion, flavour: flavour)
        )
        guard data.count <= MonMonBackupValidator.maximumByteCount else {
            throw MonMonBackupServiceError.outputTooLarge
        }
        return data
    }

    func preview(_ data: Data) throws -> ValidatedMonMonBackup {
        try MonMonBackupValidator.decodeAndValidate(data)
    }

    func loadRecovery() throws -> ValidatedMonMonBackup {
        return try MonMonBackupValidator.decodeAndValidate(
            MonMonBackupFileReader.read(recoveryURL)
        )
    }

    var hasValidRecovery: Bool {
        (try? loadRecovery()) != nil
    }

    func restore(_ incoming: ValidatedMonMonBackup) throws -> MonMonBackupRestoreReport {
        let validated: ValidatedMonMonBackup
        do {
            validated = try MonMonBackupValidator.validate(incoming.document)
        } catch {
            throw MonMonBackupServiceError.invalidSnapshot
        }

        do {
            let recoveryData = try exportData()
            _ = try MonMonBackupValidator.decodeAndValidate(recoveryData)
            try writeRecovery(recoveryData, recoveryURL)
        } catch {
            throw MonMonBackupServiceError.recoveryFailure
        }

        let context = ModelContext(container)
        context.autosaveEnabled = false
        do {
            try apply(validated.payload, in: context)
            try save(context)
        } catch {
            context.rollback()
            throw MonMonBackupServiceError.storeFailure
        }

        apply(validated.payload.preferences, to: defaults)
        // CloudKit can materialize duplicate physical rows after the snapshot
        // has been applied. The existing idempotent reconciler is the store's
        // normal post-sync guard and also refreshes those invariants here.
        _ = try? StoreReconciler.reconcile(in: context)
        return MonMonBackupRestoreReport(restoredRecordCount: validated.payload.recordCount)
    }

    private func snapshotPayload() throws -> MonMonBackupPayload {
        let context = ModelContext(container)
        context.autosaveEnabled = false
        return MonMonBackupPayload(
            accounts: try context.fetch(FetchDescriptor<CashAccount>()).map(accountRecord),
            savingsDeposits: try context.fetch(FetchDescriptor<SavingsDeposit>()).map(
                savingsDepositRecord
            ),
            savingsWithdrawals: try context.fetch(FetchDescriptor<SavingsWithdrawal>()).map(
                savingsWithdrawalRecord
            ),
            fundInstruments: try context.fetch(FetchDescriptor<FundInstrument>()).map(
                fundInstrumentRecord
            ),
            fundHoldings: try context.fetch(FetchDescriptor<FundHolding>()).map(
                fundHoldingRecord
            ),
            fundSales: try context.fetch(FetchDescriptor<FundSale>()).map(fundSaleRecord),
            budgetJars: try context.fetch(FetchDescriptor<BudgetJar>()).map(budgetJarRecord),
            goals: try context.fetch(FetchDescriptor<FinancialGoal>()).map(goalRecord),
            categories: try context.fetch(FetchDescriptor<TransactionCategory>()).map(
                categoryRecord
            ),
            transactions: try context.fetch(FetchDescriptor<MoneyTransaction>()).map(
                transactionRecord
            ),
            pendingCaptures: try context.fetch(FetchDescriptor<PendingTransactionCapture>()).map(
                pendingCaptureRecord
            ),
            transfers: try context.fetch(FetchDescriptor<AccountTransfer>()).map(transferRecord),
            debts: try context.fetch(FetchDescriptor<Debt>()).map(debtRecord),
            debtPayments: try context.fetch(FetchDescriptor<DebtPayment>()).map(debtPaymentRecord),
            recurringRules: try context.fetch(FetchDescriptor<RecurringRule>()).map(
                recurringRuleRecord
            ),
            preferences: preferenceRecord()
        )
    }

    private func accountRecord(_ model: CashAccount) -> MonMonBackupPayload.AccountRecord {
        MonMonBackupPayload.AccountRecord(
            id: MonMonBackupScalar.uuid(model.id),
            name: model.name,
            kind: model.kind.rawValue,
            openingBalance: MonMonBackupScalar.decimal(model.openingBalance),
            creditLimit: MonMonBackupScalar.decimal(model.creditLimit),
            currencyCode: model.currencyCode,
            createdAt: MonMonBackupScalar.date(model.createdAt)
        )
    }

    private func savingsDepositRecord(
        _ model: SavingsDeposit
    ) -> MonMonBackupPayload.SavingsDepositRecord {
        MonMonBackupPayload.SavingsDepositRecord(
            id: MonMonBackupScalar.uuid(model.id),
            name: model.name,
            principal: MonMonBackupScalar.decimal(model.principal),
            annualInterestRate: MonMonBackupScalar.decimal(model.annualInterestRate),
            termMonths: model.termMonths,
            openedAt: MonMonBackupScalar.date(model.openedAt),
            currencyCode: model.currencyCode,
            createdAt: MonMonBackupScalar.date(model.createdAt),
            sourceAccountID: model.sourceAccountID.map(MonMonBackupScalar.uuid)
        )
    }

    private func savingsWithdrawalRecord(
        _ model: SavingsWithdrawal
    ) -> MonMonBackupPayload.SavingsWithdrawalRecord {
        MonMonBackupPayload.SavingsWithdrawalRecord(
            id: MonMonBackupScalar.uuid(model.id),
            depositID: model.depositID.map(MonMonBackupScalar.uuid),
            principal: MonMonBackupScalar.decimal(model.principal),
            amountReceived: MonMonBackupScalar.decimal(model.amountReceived),
            destinationAccountID: MonMonBackupScalar.uuid(model.destinationAccountID),
            withdrawnAt: MonMonBackupScalar.date(model.withdrawnAt),
            note: model.note,
            currencyCode: model.currencyCode,
            createdAt: MonMonBackupScalar.date(model.createdAt)
        )
    }

    private func fundInstrumentRecord(
        _ model: FundInstrument
    ) -> MonMonBackupPayload.FundInstrumentRecord {
        MonMonBackupPayload.FundInstrumentRecord(
            id: MonMonBackupScalar.uuid(model.id),
            symbol: model.symbol,
            name: model.name,
            kind: model.kind.rawValue,
            currentPricePerUnit: MonMonBackupScalar.decimal(model.currentPricePerUnit),
            askPricePerUnit: MonMonBackupScalar.decimal(model.askPricePerUnit),
            priceAsOf: MonMonBackupScalar.date(model.priceAsOf),
            priceSource: model.priceSource,
            priceFetchedAt: model.priceFetchedAt.map(MonMonBackupScalar.date),
            autoQuoteEnabled: model.autoQuoteEnabled,
            logoURL: model.logoURL,
            currencyCode: model.currencyCode,
            createdAt: MonMonBackupScalar.date(model.createdAt)
        )
    }

    private func fundHoldingRecord(
        _ model: FundHolding
    ) -> MonMonBackupPayload.FundHoldingRecord {
        MonMonBackupPayload.FundHoldingRecord(
            id: MonMonBackupScalar.uuid(model.id),
            instrumentID: model.instrumentID.map(MonMonBackupScalar.uuid),
            units: MonMonBackupScalar.decimal(model.units),
            averageCostPerUnit: MonMonBackupScalar.decimal(model.averageCostPerUnit),
            sourceAccountID: model.sourceAccountID.map(MonMonBackupScalar.uuid),
            createdAt: MonMonBackupScalar.date(model.createdAt),
            purchasedAt: model.purchasedAt.map(MonMonBackupScalar.date)
        )
    }

    private func fundSaleRecord(_ model: FundSale) -> MonMonBackupPayload.FundSaleRecord {
        MonMonBackupPayload.FundSaleRecord(
            id: MonMonBackupScalar.uuid(model.id),
            holdingID: model.holdingID.map(MonMonBackupScalar.uuid),
            units: MonMonBackupScalar.decimal(model.units),
            pricePerUnit: MonMonBackupScalar.decimal(model.pricePerUnit),
            proceedsAccountID: MonMonBackupScalar.uuid(model.proceedsAccountID),
            soldAt: MonMonBackupScalar.date(model.soldAt),
            note: model.note,
            currencyCode: model.currencyCode,
            createdAt: MonMonBackupScalar.date(model.createdAt)
        )
    }

    private func categoryRecord(
        _ model: TransactionCategory
    ) -> MonMonBackupPayload.CategoryRecord {
        MonMonBackupPayload.CategoryRecord(
            id: MonMonBackupScalar.uuid(model.id),
            name: model.name,
            kind: model.kind.rawValue,
            symbolName: model.symbolName,
            colorName: model.colorName,
            createdAt: MonMonBackupScalar.date(model.createdAt),
            budgetJarID: model.budgetJarID.map(MonMonBackupScalar.uuid)
        )
    }

    private func budgetJarRecord(
        _ model: BudgetJar
    ) -> MonMonBackupPayload.BudgetJarRecord {
        MonMonBackupPayload.BudgetJarRecord(
            id: MonMonBackupScalar.uuid(model.id),
            name: model.name,
            allocationPercent: MonMonBackupScalar.decimal(model.allocationPercent),
            role: model.role.rawValue,
            symbolName: model.symbolName,
            colorName: model.colorName,
            createdAt: MonMonBackupScalar.date(model.createdAt)
        )
    }

    private func goalRecord(_ model: FinancialGoal) throws -> MonMonBackupPayload.GoalRecord {
        guard let fundingJarID = model.fundingJarID else {
            throw MonMonBackupServiceError.invalidSnapshot
        }
        return MonMonBackupPayload.GoalRecord(
            id: MonMonBackupScalar.uuid(model.id),
            name: model.name,
            kind: model.kind.rawValue,
            targetAmount: MonMonBackupScalar.decimal(model.targetAmount),
            earmarkedAmount: MonMonBackupScalar.decimal(model.earmarkedAmount),
            targetDate: MonMonBackupScalar.date(model.targetDate),
            monthlyContribution: MonMonBackupScalar.decimal(model.monthlyContribution),
            fundingJarID: MonMonBackupScalar.uuid(fundingJarID),
            symbolName: model.symbolName,
            colorName: model.colorName,
            createdAt: MonMonBackupScalar.date(model.createdAt)
        )
    }

    private func transactionRecord(
        _ model: MoneyTransaction
    ) -> MonMonBackupPayload.TransactionRecord {
        MonMonBackupPayload.TransactionRecord(
            id: MonMonBackupScalar.uuid(model.id),
            kind: model.kind.rawValue,
            amount: MonMonBackupScalar.decimal(model.amount),
            occurredAt: MonMonBackupScalar.date(model.occurredAt),
            note: model.note,
            accountID: MonMonBackupScalar.uuid(model.accountID),
            categoryID: model.categoryID.map(MonMonBackupScalar.uuid),
            sourceRuleID: model.sourceRuleID.map(MonMonBackupScalar.uuid),
            currencyCode: model.currencyCode,
            createdAt: MonMonBackupScalar.date(model.createdAt),
            sourceImportID: model.sourceImportID,
            incomeAllocationSnapshot: model.incomeAllocationSnapshot
        )
    }

    private func pendingCaptureRecord(
        _ model: PendingTransactionCapture
    ) -> MonMonBackupPayload.PendingCaptureRecord {
        MonMonBackupPayload.PendingCaptureRecord(
            id: MonMonBackupScalar.uuid(model.id),
            rawText: model.rawText,
            kind: model.kind.rawValue,
            amount: model.amount.map(MonMonBackupScalar.decimal),
            occurredAt: MonMonBackupScalar.date(model.occurredAt),
            note: model.note,
            accountID: model.accountID.map(MonMonBackupScalar.uuid),
            categoryID: model.categoryID.map(MonMonBackupScalar.uuid),
            issueCodes: model.issueCodes,
            createdAt: MonMonBackupScalar.date(model.createdAt)
        )
    }

    private func transferRecord(
        _ model: AccountTransfer
    ) -> MonMonBackupPayload.TransferRecord {
        MonMonBackupPayload.TransferRecord(
            id: MonMonBackupScalar.uuid(model.id),
            amount: MonMonBackupScalar.decimal(model.amount),
            occurredAt: MonMonBackupScalar.date(model.occurredAt),
            note: model.note,
            sourceAccountID: MonMonBackupScalar.uuid(model.sourceAccountID),
            destinationAccountID: MonMonBackupScalar.uuid(model.destinationAccountID),
            currencyCode: model.currencyCode,
            createdAt: MonMonBackupScalar.date(model.createdAt),
            sourceAccountImportID: model.sourceAccountImportID,
            destinationAccountImportID: model.destinationAccountImportID
        )
    }

    private func debtRecord(_ model: Debt) -> MonMonBackupPayload.DebtRecord {
        MonMonBackupPayload.DebtRecord(
            id: MonMonBackupScalar.uuid(model.id),
            counterparty: model.counterparty,
            direction: model.direction.rawValue,
            principal: MonMonBackupScalar.decimal(model.principal),
            annualInterestRate: MonMonBackupScalar.decimal(model.annualInterestRate),
            openedAt: MonMonBackupScalar.date(model.openedAt),
            dueDate: model.dueDate.map(MonMonBackupScalar.date),
            accountID: model.accountID.map(MonMonBackupScalar.uuid),
            note: model.note,
            currencyCode: model.currencyCode,
            createdAt: MonMonBackupScalar.date(model.createdAt)
        )
    }

    private func debtPaymentRecord(
        _ model: DebtPayment
    ) -> MonMonBackupPayload.DebtPaymentRecord {
        MonMonBackupPayload.DebtPaymentRecord(
            id: MonMonBackupScalar.uuid(model.id),
            debtID: model.debtID.map(MonMonBackupScalar.uuid),
            amount: MonMonBackupScalar.decimal(model.amount),
            occurredAt: MonMonBackupScalar.date(model.occurredAt),
            accountID: MonMonBackupScalar.uuid(model.accountID),
            note: model.note,
            currencyCode: model.currencyCode,
            createdAt: MonMonBackupScalar.date(model.createdAt)
        )
    }

    private func recurringRuleRecord(
        _ model: RecurringRule
    ) -> MonMonBackupPayload.RecurringRuleRecord {
        MonMonBackupPayload.RecurringRuleRecord(
            id: MonMonBackupScalar.uuid(model.id),
            kind: model.kind.rawValue,
            amount: MonMonBackupScalar.decimal(model.amount),
            note: model.note,
            accountID: MonMonBackupScalar.uuid(model.accountID),
            categoryID: model.categoryID.map(MonMonBackupScalar.uuid),
            currencyCode: model.currencyCode,
            frequency: model.frequency.rawValue,
            interval: model.interval,
            anchorDate: MonMonBackupScalar.date(model.anchorDate),
            endDate: model.endDate.map(MonMonBackupScalar.date),
            isPaused: model.isPaused,
            lastGeneratedAt: model.lastGeneratedAt.map(MonMonBackupScalar.date),
            createdAt: MonMonBackupScalar.date(model.createdAt)
        )
    }

    private func preferenceRecord() -> MonMonBackupPayload.Preferences {
        let mappings =
            defaults.dictionary(forKey: StatementAccountMapping.storageKey)
            as? [String: String] ?? [:]
        return MonMonBackupPayload.Preferences(
            theme: defaults.string(forKey: AppTheme.storageKey).flatMap(AppTheme.init)?.rawValue,
            language: defaults.string(forKey: AppLanguage.storageKey).flatMap(AppLanguage.init)?
                .rawValue,
            defaultAccountID: canonicalPreferenceUUID(TransactionDefaults.accountStorageKey),
            defaultExpenseCategoryID: canonicalPreferenceUUID(
                TransactionDefaults.categoryStorageKey),
            defaultIncomeCategoryID: canonicalPreferenceUUID(
                TransactionDefaults.incomeCategoryStorageKey
            ),
            statementAccountMappings: mappings.mapValues { value in
                UUID(uuidString: value).map(MonMonBackupScalar.uuid) ?? value
            }
        )
    }

    private func canonicalPreferenceUUID(_ key: String) -> String? {
        defaults.string(forKey: key)
            .flatMap(UUID.init(uuidString:))
            .map(MonMonBackupScalar.uuid)
    }

    private static var currentAppVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
    }

    private static func writeRecoveryData(_ data: Data, to url: URL) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        #if os(iOS)
            try data.write(to: url, options: [.atomic, .completeFileProtection])
        #else
            try data.write(to: url, options: .atomic)
        #endif
    }
}

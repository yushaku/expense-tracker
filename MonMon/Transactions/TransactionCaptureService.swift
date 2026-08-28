import Foundation
import SwiftData

enum TransactionCaptureDisposition: Equatable, Sendable {
    case transaction
    case pendingReview
}

struct TransactionCaptureCommitResult: Equatable, Sendable {
    let id: UUID
    let disposition: TransactionCaptureDisposition
}

enum TransactionCaptureServiceError: Error, Equatable, Sendable {
    case emptyCapture
    case incompleteCapture
    case staleCapture
    case storeFailure
}

@MainActor
struct TransactionCaptureService {
    private let container: ModelContainer
    private let defaults: UserDefaults

    init(container: ModelContainer, defaults: UserDefaults = .standard) {
        self.container = container
        self.defaults = defaults
    }

    func prepare(_ rawText: String, now: Date = .now) throws -> ParsedTransactionCapture {
        guard !rawText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw TransactionCaptureServiceError.emptyCapture
        }

        let context = ModelContext(container)
        do {
            let accounts = try context.fetch(FetchDescriptor<CashAccount>())
            let categories = try context.fetch(FetchDescriptor<TransactionCategory>())
            return TransactionCaptureParser.parse(
                rawText,
                context: captureContext(accounts: accounts, categories: categories),
                now: now
            )
        } catch let error as TransactionCaptureServiceError {
            throw error
        } catch {
            throw TransactionCaptureServiceError.storeFailure
        }
    }

    func prepareQuickExpense(
        _ preset: QuickExpensePreset,
        now: Date = .now
    ) throws -> ParsedTransactionCapture {
        let context = ModelContext(container)
        do {
            let accounts = try context.fetch(FetchDescriptor<CashAccount>())
            let categories = try context.fetch(FetchDescriptor<TransactionCategory>())
            let accountID = TransactionDefaults.resolveAccountID(
                defaults.string(forKey: TransactionDefaults.accountStorageKey) ?? "",
                accounts: accounts
            )
            let categoryID: UUID?
            if let configuredCategoryID = preset.categoryID {
                categoryID =
                    categories.first {
                        $0.id == configuredCategoryID && $0.kind == .expense
                    }?.id
            } else {
                categoryID = TransactionDefaults.resolveCategoryID(
                    defaults.string(forKey: TransactionDefaults.categoryStorageKey) ?? "",
                    categories: categories
                )
            }

            var issues = Set<TransactionCaptureIssue>()
            if accountID == nil {
                issues.insert(.missingAccount)
            }
            if categoryID == nil {
                issues.insert(.missingCategory)
            }

            return ParsedTransactionCapture(
                rawText: "\(VNDCurrency.formatPlain(preset.amount)) \(preset.symbol)",
                kind: .expense,
                amount: preset.amount,
                occurredAt: now,
                note: preset.symbol,
                accountID: accountID,
                categoryID: categoryID,
                issues: issues
            )
        } catch {
            throw TransactionCaptureServiceError.storeFailure
        }
    }

    func commit(
        _ capture: ParsedTransactionCapture,
        id: UUID = UUID(),
        createdAt: Date = .now
    ) throws -> TransactionCaptureCommitResult {
        let context = ModelContext(container)
        context.autosaveEnabled = false

        do {
            let disposition: TransactionCaptureDisposition
            if capture.isReady {
                try insertTransaction(for: capture, id: id, createdAt: createdAt, in: context)
                disposition = .transaction
            } else {
                guard !capture.rawText.isEmpty else {
                    throw TransactionCaptureServiceError.emptyCapture
                }
                context.insert(
                    PendingTransactionCapture(id: id, capture: capture, createdAt: createdAt))
                disposition = .pendingReview
            }

            try context.save()
            return TransactionCaptureCommitResult(id: id, disposition: disposition)
        } catch let error as TransactionCaptureServiceError {
            context.rollback()
            throw error
        } catch {
            context.rollback()
            throw TransactionCaptureServiceError.storeFailure
        }
    }

    private func captureContext(
        accounts: [CashAccount],
        categories: [TransactionCategory]
    ) -> TransactionCaptureContext {
        let expenseValue = defaults.string(forKey: TransactionDefaults.categoryStorageKey) ?? ""
        let incomeValue =
            defaults.string(forKey: TransactionDefaults.incomeCategoryStorageKey) ?? ""

        return TransactionCaptureContext(
            accounts: accounts.map {
                CaptureAccount(id: $0.id, name: $0.name, isCash: $0.kind == .normal)
            },
            categories: categories.map {
                CaptureCategory(
                    id: $0.id,
                    name: $0.name,
                    kind: $0.kind,
                    symbolName: $0.symbolName
                )
            },
            defaultAccountID: TransactionDefaults.resolveAccountID(
                defaults.string(forKey: TransactionDefaults.accountStorageKey) ?? "",
                accounts: accounts
            ),
            defaultExpenseCategoryID: TransactionDefaults.resolveCategoryID(
                expenseValue,
                categories: categories
            ),
            defaultIncomeCategoryID: TransactionDefaults.resolveCategoryID(
                incomeValue,
                categories: categories,
                kind: .income
            )
        )
    }

    private func insertTransaction(
        for capture: ParsedTransactionCapture,
        id: UUID,
        createdAt: Date,
        in context: ModelContext
    ) throws {
        guard
            let amount = capture.amount,
            amount > 0,
            let accountID = capture.accountID,
            let categoryID = capture.categoryID
        else {
            throw TransactionCaptureServiceError.staleCapture
        }

        let accounts = try context.fetch(FetchDescriptor<CashAccount>())
        let categories = try context.fetch(FetchDescriptor<TransactionCategory>())
        guard accounts.contains(where: { $0.id == accountID }),
            categories.contains(where: { $0.id == categoryID && $0.kind == capture.kind })
        else {
            throw TransactionCaptureServiceError.staleCapture
        }

        let draft = TransactionDraft(
            kind: capture.kind,
            amountText: VNDCurrency.formatPlain(amount),
            occurredAt: capture.occurredAt,
            note: capture.note,
            accountID: accountID,
            categoryID: categoryID
        )
        do {
            context.insert(try draft.makeTransaction(id: id, createdAt: createdAt))
        } catch {
            throw TransactionCaptureServiceError.staleCapture
        }
    }
}

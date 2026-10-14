import Foundation
import SwiftData

@Model
final class PendingTransactionCapture {
    var id: UUID = UUID()
    var rawText: String = ""
    var kind: TransactionKind = TransactionKind.expense
    var amount: Decimal?
    var occurredAt: Date = Date(timeIntervalSince1970: 0)
    var note: String = ""
    var accountID: UUID?
    var categoryID: UUID?
    var issueCodes: String = ""
    var createdAt: Date = Date(timeIntervalSince1970: 0)

    init(id: UUID, capture: ParsedTransactionCapture, createdAt: Date) {
        self.id = id
        rawText = capture.rawText
        kind = capture.kind
        amount = capture.amount
        occurredAt = capture.occurredAt
        note = capture.note
        accountID = capture.accountID
        categoryID = capture.categoryID
        issueCodes = capture.issues.map(\.rawValue).sorted().joined(separator: ",")
        self.createdAt = createdAt
    }

    init(
        id: UUID,
        rawText: String,
        kind: TransactionKind,
        amount: Decimal?,
        occurredAt: Date,
        note: String,
        accountID: UUID?,
        categoryID: UUID?,
        issueCodes: String,
        createdAt: Date
    ) {
        self.id = id
        self.rawText = rawText
        self.kind = kind
        self.amount = amount
        self.occurredAt = occurredAt
        self.note = note
        self.accountID = accountID
        self.categoryID = categoryID
        self.issueCodes = issueCodes
        self.createdAt = createdAt
    }

    var issues: Set<TransactionCaptureIssue> {
        Set(
            issueCodes.split(separator: ",").compactMap {
                TransactionCaptureIssue(rawValue: String($0))
            })
    }

    var draft: TransactionDraft {
        TransactionDraft(
            kind: kind,
            amountText: amount.map(VNDCurrency.formatPlain) ?? "",
            occurredAt: occurredAt,
            note: note,
            accountID: accountID,
            categoryID: categoryID
        )
    }
}

struct DeletedPendingCapture: Identifiable {
    let id: UUID
    let rawText: String
    let kind: TransactionKind
    let amount: Decimal?
    let occurredAt: Date
    let note: String
    let accountID: UUID?
    let categoryID: UUID?
    let issueCodes: String
    let createdAt: Date

    init(_ capture: PendingTransactionCapture) {
        id = capture.id
        rawText = capture.rawText
        kind = capture.kind
        amount = capture.amount
        occurredAt = capture.occurredAt
        note = capture.note
        accountID = capture.accountID
        categoryID = capture.categoryID
        issueCodes = capture.issueCodes
        createdAt = capture.createdAt
    }

    func makeCapture() -> PendingTransactionCapture {
        PendingTransactionCapture(
            id: id, rawText: rawText, kind: kind, amount: amount,
            occurredAt: occurredAt, note: note, accountID: accountID,
            categoryID: categoryID, issueCodes: issueCodes, createdAt: createdAt
        )
    }
}

@MainActor
enum PendingCaptureDeletion {
    static func delete(_ capture: PendingTransactionCapture, from context: ModelContext) throws
        -> DeletedPendingCapture
    {
        let snapshot = DeletedPendingCapture(capture)
        context.delete(capture)
        do {
            try SyncWriteGate.save(context)
            return snapshot
        } catch {
            context.rollback()
            throw error
        }
    }

    static func restore(_ snapshot: DeletedPendingCapture, in context: ModelContext) throws {
        context.insert(snapshot.makeCapture())
        do {
            try SyncWriteGate.save(context)
        } catch {
            context.rollback()
            throw error
        }
    }
}

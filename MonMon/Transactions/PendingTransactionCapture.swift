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

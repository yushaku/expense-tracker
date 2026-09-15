import CryptoKit
import Foundation

enum BankNotificationPreferences {
    static let accountKey = "bankNotification.accountID"
    static let automaticSaveKey = "bankNotification.automaticSave"
    static let lastResultKey = "bankNotification.lastResult"
    static let lastReceivedKey = "bankNotification.lastReceived"
}

struct BankNotificationEvent: Sendable {
    let text: String
    let source: String
    let receivedAt: Date

    var rawText: String { "[\(source.trimmingCharacters(in: .whitespacesAndNewlines))]\n\(text)" }

    var note: String {
        let contentLines = text.split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { $0.hasPrefix("ND:") }
        guard contentLines.count == 1, let line = contentLines.first else { return rawText }
        let content = line.dropFirst(3).trimmingCharacters(in: .whitespaces)
        return content.isEmpty ? rawText : content
    }

    /// Include the original event date: equal-valued payments at different times
    /// must remain distinct. Callers must reuse that date when retrying an event.
    func id(accountID: UUID) -> UUID {
        let fields = [
            "bank-notification-v1", source, accountID.uuidString, text,
            String(receivedAt.timeIntervalSince1970),
        ]
        let payload = fields.map { "\($0.utf8.count):\($0)" }.joined()
        var bytes = Array(SHA256.hash(data: Data(payload.utf8)).prefix(16))
        bytes[6] = (bytes[6] & 0x0f) | 0x80
        bytes[8] = (bytes[8] & 0x3f) | 0x80
        return UUID(
            uuid: (
                bytes[0], bytes[1], bytes[2], bytes[3], bytes[4], bytes[5], bytes[6], bytes[7],
                bytes[8], bytes[9], bytes[10], bytes[11], bytes[12], bytes[13], bytes[14], bytes[15]
            ))
    }
}

enum BankNotificationParser {
    // Deliberately narrow until real bank samples are verified. Only a labelled
    // transaction at the start of the notification can supply the amount. Never
    // reuse natural-language capture: it also finds account numbers and balances.
    private static let transaction = try? NSRegularExpression(
        pattern:
            #"^\s*(?:gd|giao dich|transaction)\s*:\s*([+-])\s*([0-9]+(?:[.,][0-9]+)*)\s*(?:vnd|d)(?=\s|[;,]|$)"#,
        options: [.caseInsensitive]
    )
    private static let groupedAmount = try? NSRegularExpression(
        pattern: #"^(?:[0-9]+|[0-9]{1,3}(?:\.[0-9]{3})+|[0-9]{1,3}(?:,[0-9]{3})+)$"#
    )
    private static let signedAmounts = try? NSRegularExpression(
        pattern: #"[+-]\s*[0-9]+(?:[.,][0-9]+)*\s*(?:vnd|d)(?=\s|[;,]|$)"#
    )
    private static let transferAbbreviations = try? NSRegularExpression(
        pattern: #"\b(?:ck|ft)\b"#
    )

    static func parse(
        _ event: BankNotificationEvent,
        accountID: UUID,
        context: TransactionCaptureContext,
        automaticSave: Bool
    ) -> ParsedTransactionCapture {
        let normalized = event.text.folding(
            options: [.diacriticInsensitive, .caseInsensitive],
            locale: Locale(identifier: "vi_VN")
        ).replacingOccurrences(of: "đ", with: "d")
        let range = NSRange(normalized.startIndex..<normalized.endIndex, in: normalized)
        var issues: Set<TransactionCaptureIssue> = []
        var amount: Decimal?
        var kind = TransactionKind.expense
        if let match = transaction?.firstMatch(in: normalized, range: range),
            let signRange = Range(match.range(at: 1), in: normalized),
            let amountRange = Range(match.range(at: 2), in: normalized)
        {
            kind = normalized[signRange] == "+" ? .income : .expense
            let number = String(normalized[amountRange])
            let numberRange = NSRange(number.startIndex..<number.endIndex, in: number)
            if groupedAmount?.firstMatch(in: number, range: numberRange) != nil {
                let digits = number.filter(\.isNumber)
                if digits.count <= 15,
                    let value = Decimal(string: digits, locale: Locale(identifier: "en_US_POSIX")),
                    value > 0
                {
                    amount = value
                }
            }
        }
        if amount == nil { issues.insert(.missingAmount) }

        // Transfers, requests, failures and authentication messages aren't proof
        // of a completed income/expense. Keep their text for the user's review.
        let reviewWords = [
            "otp", "xac thuc", "verification", "that bai", "failed", "declined",
            "pending", "dang xu ly", "yeu cau", "request", "du kien", "scheduled",
            "chuyen", "transfer", "thanh toan the", "credit card payment", "huy", "cancel",
            "khong thanh cong", "tu choi", "khong thuc hien", "hoan", "reversed", "reversal",
        ]
        if !automaticSave || reviewWords.contains(where: { normalized.contains($0) }) {
            issues.insert(.notificationNeedsReview)
        }
        if transferAbbreviations?.firstMatch(in: normalized, range: range) != nil {
            issues.insert(.notificationNeedsReview)
        }
        // Multiple signed amounts may be multiple movements, even when a second
        // label is absent. An ambiguous signed balance also stays in review.
        if signedAmounts?.numberOfMatches(in: normalized, range: range) != 1 {
            issues.insert(.notificationNeedsReview)
        }

        let categoryID =
            kind == .expense
            ? context.defaultExpenseCategoryID : context.defaultIncomeCategoryID
        if !context.categories.contains(where: { $0.id == categoryID && $0.kind == kind }) {
            issues.insert(.missingCategory)
        }
        return ParsedTransactionCapture(
            rawText: event.rawText,
            kind: kind,
            amount: amount,
            occurredAt: event.receivedAt,
            note: event.note,
            accountID: accountID,
            categoryID: issues.contains(.missingCategory) ? nil : categoryID,
            issues: issues
        )
    }
}

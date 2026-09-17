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
    // Deliberately narrow: only a whitelisted movement label that opens a line or
    // a `|`/`;` separated segment can supply the amount. Balance labels (`SD`,
    // `SO DU`, `SD KHA DUNG`, `BALANCE`) and account lines (`TK`) are outside the
    // whitelist, so they can never be read as a movement. Never reuse
    // natural-language capture: it also finds account numbers and balances.
    private static let movementLabel =
        #"(?:gd|giao dich|transaction|ps|so tien|amount|bien dong)"#
    /// Digits grouped by `.`, `,` or any Unicode space separator (issuers emit
    /// U+00A0 inside amounts such as `50 000`).
    private static let amountDigits = #"[0-9]+(?:[.,\p{Zs}][0-9]+)*"#
    /// `đ`/`Đ` are folded to `d` before matching, so `VNĐ` arrives here as `vnd`.
    /// The lookahead only rejects a longer word, which lets `.`, `)`, `|`, `;`
    /// and end of line terminate the amount.
    private static let currencySuffix = #"\s*(?:vnd|d)(?![0-9a-z])"#
    private static let transaction = try? NSRegularExpression(
        pattern:
            #"(?:^|[|;])[\p{Zs}]*"# + movementLabel + #"\s*:\s*([+-]?)\s*("# + amountDigits + #")"#
            + currencySuffix,
        options: [.caseInsensitive, .anchorsMatchLines]
    )
    /// One integer, or groups of three behind a single consistent separator.
    private static let groupedInteger = try? NSRegularExpression(
        pattern: #"^(?:[0-9]+|[0-9]{1,3}(?:\.[0-9]{3})+|[0-9]{1,3}(?:,[0-9]{3})+)$"#
    )
    private static let signedAmounts = try? NSRegularExpression(
        pattern: #"[+-]\s*"# + amountDigits + currencySuffix,
        options: [.caseInsensitive]
    )
    private static let transferAbbreviations = try? NSRegularExpression(
        pattern: #"\b(?:ck|ft)\b"#
    )

    /// Reads a Vietnamese bank amount without ever concatenating its digits: a
    /// trailing `,00` or `.00` is a fraction, not three more thousands. The
    /// decimal separator is the last `.`/`,` followed by one or two digits;
    /// every other separator groups thousands. Unicode spaces group thousands too.
    private static func decimal(from text: String) -> Decimal? {
        let compact = String(text.unicodeScalars.filter { !$0.properties.isWhitespace })
        var integerText = compact
        var fractionText = ""
        if let separator = compact.lastIndex(where: { $0 == "." || $0 == "," }) {
            let fraction = compact[compact.index(after: separator)...]
            if fraction.count <= 2 {
                integerText = String(compact[..<separator])
                fractionText = String(fraction)
            }
        }
        let integerRange = NSRange(integerText.startIndex..<integerText.endIndex, in: integerText)
        guard groupedInteger?.firstMatch(in: integerText, range: integerRange) != nil else {
            return nil
        }
        let digits = integerText.filter(\.isNumber)
        guard !digits.isEmpty, digits.count <= 15 else { return nil }
        let normalized = fractionText.isEmpty ? digits : "\(digits).\(fractionText)"
        return Decimal(string: normalized, locale: Locale(identifier: "en_US_POSIX"))
    }

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
            if let value = decimal(from: String(normalized[amountRange])), value > 0 {
                amount = value
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

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
    /// Labels that introduce free text the payer typed rather than a status the
    /// bank asserts. A Vietnamese credit almost always carries "chuyen tien" or
    /// "chuyen khoan" there, often a given name such as "Huy", and "hoan thanh"
    /// means completed rather than refunded. Scanning that text for status
    /// words blocked nearly every legitimate credit, so it is cut out of the
    /// status scan. It stays in `BankNotificationEvent.note` for the user.
    private static let contentLabel = try? NSRegularExpression(
        pattern: #"^[\p{Zs}]*(?:nd|noi dung|content|message|remark|mo ta|ghi chu|dien giai)\s*:"#,
        options: [.caseInsensitive]
    )
    /// Transfers, requests, failures and authentication messages aren't proof
    /// of a completed income/expense. Keep their text for the user's review.
    ///
    /// Matched on word boundaries rather than as substrings: `huy` must not
    /// fire on the name "Huy", `hoan tien` must not be reached by "hoan thanh",
    /// and `chuyen` must not fire on "chuyen doi".
    private static let reviewWords = try? NSRegularExpression(
        pattern: #"\b(?:"#
            + [
                "otp", "xac thuc", "verification", "that bai", "failed", "fail",
                "declined", "decline", "pending", "dang xu ly", "cho xu ly",
                "yeu cau", "request", "requested", "du kien", "scheduled",
                "chuyen", "transfer", "transferred", "thanh toan the",
                "credit card payment", "huy", "cancel", "cancelled", "canceled",
                "khong thanh cong", "tu choi", "khong thuc hien",
                "hoan tien", "hoan tra", "refund", "refunded", "reversed", "reversal",
            ].joined(separator: "|") + #")\b"#,
        options: [.caseInsensitive]
    )

    /// The part of the payload the bank asserts about the movement: every
    /// newline, `|` or `;` separated segment except the payer's free text.
    private static func bankAssertedText(in normalized: String) -> String {
        normalized
            .split(whereSeparator: { $0.isNewline || $0 == "|" || $0 == ";" })
            .filter { segment in
                let text = String(segment)
                let range = NSRange(text.startIndex..<text.endIndex, in: text)
                return contentLabel?.firstMatch(in: text, range: range) == nil
            }
            .joined(separator: "\n")
    }

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

        // Status words are read only from what the bank asserts, never from the
        // payer's free text: a legitimate credit says "chuyen tien" there.
        let asserted = bankAssertedText(in: normalized)
        let assertedRange = NSRange(asserted.startIndex..<asserted.endIndex, in: asserted)
        if !automaticSave || reviewWords?.firstMatch(in: asserted, range: assertedRange) != nil {
            issues.insert(.notificationNeedsReview)
        }
        // `CK`/`FT` in the payer's free text is the payer's shorthand for the
        // transfer they just made, not a bank status, so it is read from the
        // asserted text too.
        if transferAbbreviations?.firstMatch(in: asserted, range: assertedRange) != nil {
            issues.insert(.notificationNeedsReview)
        }
        // Multiple signed amounts may be multiple movements, even when a second
        // label is absent. An ambiguous signed balance also stays in review.
        if signedAmounts?.numberOfMatches(in: normalized, range: range) != 1 {
            issues.insert(.notificationNeedsReview)
        }

        let defaultCategoryID =
            kind == .expense
            ? context.defaultExpenseCategoryID : context.defaultIncomeCategoryID
        let categoryID =
            TransactionCategoryClassifier.classify(
                event.note,
                kind: kind,
                categories: context.categories,
                strategy: .englishFirst
            ).categoryID ?? defaultCategoryID
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

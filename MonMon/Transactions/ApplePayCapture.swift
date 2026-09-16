import CryptoKit
import Foundation

enum ApplePayPreferences {
    static let accountKey = "applePay.accountID"
    static let automaticSaveKey = "applePay.automaticSave"
    static let lastResultKey = "applePay.lastResult"
    static let lastReceivedKey = "applePay.lastReceived"
}

/// Supplied by the user's Wallet automation, not a verified bank settlement.
struct ApplePayEvent: Sendable {
    let amount: Decimal?
    let currency: String
    let merchant: String
    let occurredAt: Date
    var card: String = ""

    var currencyCode: String {
        currency.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
    }
    var note: String { merchant.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var cardLabel: String { card.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var amountText: String { amount.map { NSDecimalNumber(decimal: $0).stringValue } ?? "" }

    var rawText: String {
        "[Apple Pay]\nAmount: \(amountText)\nCurrency: \(currencyCode)\nMerchant: \(note)\nCard: \(cardLabel)"
    }

    func validate() throws {
        guard merchant.utf8.count <= 1024, currency.utf8.count <= 16, card.utf8.count <= 256,
            occurredAt.timeIntervalSince1970.isFinite,
            occurredAt >= Date(timeIntervalSince1970: 0), occurredAt <= .distantFuture
        else { throw TransactionCaptureServiceError.emptyCapture }
    }

    /// Replays must reuse the original event date and destination. New timestamps
    /// and other capture sources are intentionally not treated as exact retries.
    func id(accountID: UUID?) -> UUID {
        let fields = [
            "apple-pay-v1", accountID?.uuidString ?? "", amountText, currencyCode,
            note, cardLabel, String(occurredAt.timeIntervalSince1970),
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

    func capture(accountID: UUID?, categoryID: UUID?, automaticSave: Bool)
        -> ParsedTransactionCapture
    {
        var issues = Set<TransactionCaptureIssue>()
        var vndAmount: Decimal?
        if currencyCode != VNDCurrency.code {
            issues.insert(.unsupportedCurrency)
        } else if var amount, !amount.isNaN, amount > 0, amount < 1_000_000_000_000_000 {
            var rounded = Decimal()
            NSDecimalRound(&rounded, &amount, 0, .plain)
            if rounded == amount { vndAmount = amount }
        }
        if vndAmount == nil { issues.insert(.missingAmount) }
        if accountID == nil { issues.insert(.missingAccount) }
        if categoryID == nil { issues.insert(.missingCategory) }
        if !automaticSave || note.isEmpty { issues.insert(.applePayNeedsReview) }
        return ParsedTransactionCapture(
            rawText: rawText, kind: .expense, amount: vndAmount, occurredAt: occurredAt,
            note: note, accountID: accountID, categoryID: categoryID, issues: issues)
    }
}

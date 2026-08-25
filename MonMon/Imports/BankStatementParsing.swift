import CryptoKit
import Foundation

protocol BankStatementParsing: Sendable {
    func parse(_ data: Data) throws -> ParsedBankStatement
}

enum BankStatementBank: String, Sendable {
    case tpBank = "tpbank"
}

struct BankStatementTotals: Sendable, Equatable {
    let debit: Decimal
    let credit: Decimal
}

enum BankStatementIssue: Sendable, Equatable {
    case ambiguousAmount(page: Int, row: Int)
    case invalidRow(page: Int, row: Int)
    case totalsMismatch
}

enum BankStatementParserError: Error, Sendable, Equatable {
    case unsupportedFormat
    case encryptedDocument
    case missingTextLayer
    case unrecognizedLayout
    case invalidStatementMetadata
    case noTransactionRows
}

struct ParsedBankStatement: Sendable, Equatable {
    let bank: BankStatementBank
    let accountLastFour: String?
    let currencyCode: String
    let period: ClosedRange<Date>
    let candidates: [BankTransactionCandidate]
    let declaredTotals: BankStatementTotals?
    let parsedTotals: BankStatementTotals
    let issues: [BankStatementIssue]

    var isComplete: Bool {
        issues.isEmpty && declaredTotals == parsedTotals
    }
}

struct BankTransactionCandidate: Sendable, Equatable, Identifiable {
    let id: String
    let occurredAt: Date
    let kind: TransactionKind
    let amount: Decimal
    let note: String
    let sourceReference: String
    let sourcePage: Int

    var signedAmount: Decimal {
        kind == .income ? amount : -amount
    }

    static func makeID(
        bank: BankStatementBank,
        accountLastFour: String?,
        occurredAt: Date,
        kind: TransactionKind,
        amount: Decimal,
        sourceReference: String
    ) -> String {
        let fields = [
            bank.rawValue,
            BankStatementNormalization.accountLastFour(from: accountLastFour ?? "") ?? "",
            String(occurredAt.timeIntervalSince1970.bitPattern, radix: 16),
            kind.rawValue,
            NSDecimalNumber(decimal: amount).stringValue,
            sourceReference.trimmingCharacters(in: .whitespacesAndNewlines),
        ]
        let canonical = fields.map { "\($0.utf8.count):\($0)" }.joined()
        let digest = SHA256.hash(data: Data(canonical.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}

enum BankStatementNormalization {
    static func accountLastFour(from source: String) -> String? {
        let digits = source.unicodeScalars.filter { (48...57).contains($0.value) }
        guard digits.count >= 4 else {
            return nil
        }
        return String(String.UnicodeScalarView(digits.suffix(4)))
    }
}

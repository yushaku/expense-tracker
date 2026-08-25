import Foundation
import Testing

@testable import MonMon

@Suite("Bank statement parser contract")
struct BankStatementParsingTests {
    private let occurredAt = Date(timeIntervalSince1970: 1_700_000_000)

    @Test("Direction changes the sign while imported amounts stay positive")
    func candidateAmountConventionMatchesTransactions() {
        let expense = makeCandidate(kind: .expense, amount: 125_000)
        let income = makeCandidate(kind: .income, amount: 500_000)

        #expect(expense.amount == 125_000)
        #expect(expense.signedAmount == -125_000)
        #expect(income.amount == 500_000)
        #expect(income.signedAmount == 500_000)
    }

    @Test("A parsed statement is complete only when issues are absent and totals match")
    func completenessRequiresExactReconciliation() {
        let totals = BankStatementTotals(debit: 125_000, credit: 500_000)
        let period = occurredAt...occurredAt.addingTimeInterval(86_400)

        let complete = ParsedBankStatement(
            bank: .tpBank,
            accountLastFour: "9012",
            currencyCode: "VND",
            period: period,
            candidates: [],
            declaredTotals: totals,
            parsedTotals: totals,
            issues: []
        )
        let mismatched = ParsedBankStatement(
            bank: .tpBank,
            accountLastFour: "9012",
            currencyCode: "VND",
            period: period,
            candidates: [],
            declaredTotals: totals,
            parsedTotals: BankStatementTotals(debit: 124_000, credit: 500_000),
            issues: []
        )
        let uncertain = ParsedBankStatement(
            bank: .tpBank,
            accountLastFour: "9012",
            currencyCode: "VND",
            period: period,
            candidates: [],
            declaredTotals: totals,
            parsedTotals: totals,
            issues: [.totalsMismatch]
        )

        #expect(complete.isComplete)
        #expect(!mismatched.isComplete)
        #expect(!uncertain.isComplete)
    }

    @Test("Candidate identity is deterministic and does not expose source identifiers")
    func candidateIdentityIsStableAndOpaque() {
        let first = BankTransactionCandidate.makeID(
            bank: .tpBank,
            accountLastFour: "9012",
            occurredAt: occurredAt,
            kind: .expense,
            amount: 125_000,
            sourceReference: "FAKE-REFERENCE-001"
        )
        let second = BankTransactionCandidate.makeID(
            bank: .tpBank,
            accountLastFour: "9012",
            occurredAt: occurredAt,
            kind: .expense,
            amount: 125_000,
            sourceReference: "FAKE-REFERENCE-001"
        )

        #expect(first == second)
        #expect(first.count == 64)
        #expect(!first.contains("9012"))
        #expect(!first.contains("FAKE-REFERENCE-001"))
    }

    @Test("Account normalization returns only four trailing ASCII digits")
    func accountNormalizationMinimizesIdentityData() {
        #expect(
            BankStatementNormalization.accountLastFour(from: "Account 1234 5678 9012")
                == "9012"
        )
        #expect(BankStatementNormalization.accountLastFour(from: "Account 123") == nil)
        #expect(BankStatementNormalization.accountLastFour(from: "No account") == nil)
    }

    private func makeCandidate(kind: TransactionKind, amount: Decimal) -> BankTransactionCandidate {
        BankTransactionCandidate(
            id: "fake-id",
            occurredAt: occurredAt,
            kind: kind,
            amount: amount,
            note: "Synthetic note",
            sourceReference: "FAKE-REFERENCE-001",
            sourcePage: 1
        )
    }
}

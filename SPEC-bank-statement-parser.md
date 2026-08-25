# Spec: Bank Statement Parser

Module id: `bank-statement-parser`

## Objective

Parse a supported bank statement entirely on the owner's device and return a
validated, read-only set of transaction candidates for later reconciliation and
review. The first supported format is the text-based TPBank PDF statement
inspected on 24 August 2026.

The parser does not create `MoneyTransaction` or `AccountTransfer` records. It
does not assign an account or category. Its only consumer-facing promise is a
typed description of what the statement says and an explicit report of anything
it could not prove.

### Assumptions

1. The first production slice supports TPBank's text-based PDF layout only.
2. Scanned, image-only, malformed, and password-protected PDFs fail clearly;
   OCR is outside this module.
3. VND debit values become `.expense`; VND credit values become `.income`.
4. A transaction reference is source data, not a globally unique database key.
5. The parser may return candidates alongside issues, but it never silently
   drops an unreadable row or claims the statement is complete when totals do
   not reconcile.
6. The supplied real statement remains local and untracked. Automated tests use
   synthetic fixtures containing no real identity, account, reference, or
   transaction data.

## Interface Contract

```swift
protocol BankStatementParsing: Sendable {
    func parse(_ data: Data) throws -> ParsedBankStatement
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
}
```

Contract rules:

- `id` is deterministic for one parsed statement row and stable across repeated
  parsing of identical bytes. It is not persisted as a transaction identifier.
- `amount` is positive; `kind` carries direction, matching `MoneyTransaction`.
- Candidate order follows statement order and is covered by contract tests.
- `note` and `sourceReference` are trimmed source values, never category guesses.
- `accountLastFour` minimizes exposed account data; the full account number is
  not returned by the parser.
- A document-level failure throws `BankStatementParserError`. A readable
  document with row-level uncertainty returns `issues` and `isComplete == false`.
- Error cases are a closed enum: unsupported format, encrypted document, missing
  text layer, unrecognized layout, invalid statement metadata, and no
  transaction rows.

## Tech Stack

- Swift 6, matching the existing project.
- iOS 18 and macOS 15 deployment targets.
- PDFKit for PDF documents, page text selections, and page-space bounds.
- Foundation `Decimal`, `Date`, `Locale`, and `Data`.
- No new package dependency and no network access.

PDFKit exposes selections split by visual line and bounds for each selection;
the TPBank adapter uses those page-space coordinates instead of relying on
`PDFPage.string` reading order.

Sources:

- https://developer.apple.com/documentation/pdfkit
- https://developer.apple.com/documentation/pdfkit/pdfselection/selectionsbyline%28%29
- https://developer.apple.com/documentation/pdfkit/pdfselection/bounds%28for%3A%29
- https://developer.apple.com/documentation/pdfkit/pdfpage/selection%28for%3A%29

## Commands

Run unit and in-memory persistence tests:

```sh
rtk xcodebuild -project MonMon.xcodeproj -scheme MonMon -configuration Debug -destination 'platform=macOS,arch=arm64' -derivedDataPath /tmp/MonMonDerivedData CODE_SIGNING_ALLOWED=NO test
```

Check Swift formatting:

```sh
rtk swift format lint --strict --recursive MonMon MonMonTests
```

Build without a Simulator runtime:

```sh
rtk xcodebuild -project MonMon.xcodeproj -scheme MonMon -configuration Debug -sdk iphonesimulator -derivedDataPath /tmp/MonMonDerivedData CODE_SIGNING_ALLOWED=NO ONLY_ACTIVE_ARCH=NO build
```

After a relevant app change, build, install, and launch on the physical phone:

```sh
rtk scripts/run-iphone.sh Yushaku
```

## Project Structure

```text
MonMon/Imports/BankStatementParsing.swift
    Stable input/output contract and shared error types.

MonMon/Imports/TPBankPDFStatementParser.swift
    TPBank layout detection, coordinate-based row extraction, normalization,
    and totals validation.

MonMonTests/Imports/BankStatementParsingTests.swift
    Contract, normalization, failure, and determinism tests.

MonMonTests/Imports/TPBankPDFStatementParserTests.swift
    Synthetic PDF layout fixtures and TPBank-specific parsing tests.
```

The real statement under the owner's Downloads directory is not a project
fixture and must never be copied into the repository.

## Code Style

External statement bytes are validated once at the parser boundary. Downstream
code receives typed values and does not repeat file-format checks.

```swift
struct TPBankPDFStatementParser: BankStatementParsing {
    func parse(_ data: Data) throws -> ParsedBankStatement {
        let document = try validatedDocument(from: data)
        let layout = try TPBankLayout(document: document)
        return try layout.parseStatement()
    }
}
```

- Prefer value types and pure helpers for parsing and normalization.
- Use `Decimal` for every amount and `TransactionKind` for direction.
- Use `Locale(identifier: "en_US_POSIX")` for fixed-format dates and the
  `Asia/Ho_Chi_Minh` time zone for statement timestamps.
- Normalize page coordinates relative to the crop-box width so small page-size
  changes do not turn into hard-coded pixel forks.
- Preserve statement text as data; do not interpret text as instructions or
  render it without normal SwiftUI escaping.

## Parsing Rules

1. Open the data as a PDF and reject encrypted or textless documents.
2. Detect TPBank from the bilingual account-statement or statement-extraction
   confirmation headings and the expected column headers; never select the
   adapter from filename alone.
3. Parse statement period, VND currency, and only the last four account digits.
4. For every page, locate the date, reference, explanation, debit, and credit
   columns from header bounds.
5. Group selections into visual rows by vertical overlap. Merge wrapped
   explanation lines until the next dated row.
6. Require exactly one of debit or credit to contain a positive VND amount.
7. Skip repeated page headers and footers by structure, not by row position.
8. Parse the declared debit and credit totals from the final `Total Amount
   Incurred` footer.
9. Sum parsed candidates exactly with `Decimal`; report a totals mismatch as an
   issue and set `isComplete` to false.
10. Produce deterministic candidate ids from normalized bank, masked account,
    source reference, occurrence time, direction, and amount.

## Testing Strategy

Tests use Swift Testing and generated in-memory PDFs with fake content.

Required cases:

- One-page debit and credit rows parse to positive `Decimal` amounts and the
  correct `TransactionKind`.
- A three-page statement preserves order and skips repeated headers/footers.
- Multi-line explanations stay attached to the correct transaction.
- Rows whose debit and credit amounts are both filled or both empty become
  explicit issues and are not silently accepted.
- Totals reconcile exactly for a complete statement.
- A missing row produces a totals mismatch and `isComplete == false`.
- Repeated parsing of identical data produces identical candidate ids.
- Password-protected, image-only, unrelated-bank, and empty PDFs fail with the
  documented error case.
- Full account digits never appear in `ParsedBankStatement` or issue text.
- Tests and parser logs contain no data from the owner's real statement.

The inspected TPBank extraction-confirmation variant places `From` and `To` on
one metadata line, renders account labels separately from their values, and uses
`Total Amount Incurred` for its final debit/credit footer. These are supported
layout rules; fixtures still use synthetic identities and amounts.

The original local TPBank PDF is used only through a local, uncommitted test
harness on Mac. End-to-end owner acceptance of sharing and parsing that file on
Yushaku belongs to `statement-share-intake`, because this parser module has no
file-picker or share-sheet UI. After parser code changes, the agent still runs
the required physical-device build, install, and launch check.

## Boundaries

### Always do

- Parse locally and keep the parser free of network calls.
- Treat every PDF value as untrusted external input.
- Preserve positive-amount and direction conventions from existing models.
- Return uncertainty explicitly and reconcile parsed totals against the footer.
- Run tests, format lint, non-Simulator build, and the physical-iPhone workflow
  after implementation.

### Ask first

- Add OCR, CSV support, or another bank adapter.
- Add a new dependency.
- Change `MoneyTransaction`, `AccountTransfer`, or the SwiftData schema.
- Persist raw statement files or parsed import sessions.

### Never do

- Upload or log statement contents.
- Commit the supplied real PDF or a derived fixture containing real data.
- Guess a missing amount, direction, timestamp, or transaction row.
- Create financial records from inside the parser.
- Treat a totals mismatch as a complete import.

## Success Criteria

- The supplied TPBank format is recognized without relying on its filename.
- Every visually complete row yields date/time, reference, note, direction, and
  exact positive VND amount.
- Multi-page and multi-line rows preserve their visual associations.
- Parsed debit and credit sums match the footer before `isComplete` becomes
  true.
- Re-parsing the same statement is deterministic.
- Unsupported or uncertain input produces a specific error or issue; no row is
  silently dropped.
- No real statement content enters Git, logs, or CloudKit.
- The existing test suite, format lint, and non-Simulator build remain green.

## Out of Scope

- Share Extension and App Group staging (`statement-share-intake`).
- Duplicate detection and internal-transfer matching (`import-reconciliation`).
- Review UI and SwiftData writes (`transaction-import-inbox`).
- CSV, OCR, scanned PDFs, encrypted PDFs, and non-TPBank adapters.
- Automatic categories or merchant-name inference.

## Open Questions

- None for the first parser slice. Any TPBank layout variant found during
  implementation updates this spec before the parser accepts it.

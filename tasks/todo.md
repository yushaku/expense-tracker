# Tasks: TPBank PDF Statement Parser

## Task 1: Define parser contract and normalization primitives

**Description:** Add the stable parser input/output types, closed error and
issue semantics, exact totals, deterministic candidate identity helper, and
Imports groups in the Xcode project. Start with failing contract tests.

**Acceptance criteria:**

- [x] Positive amounts and `TransactionKind` represent direction consistently
      with `MoneyTransaction`.
- [x] `isComplete` requires no issues and exact declared/parsed totals.
- [x] Candidate ids are deterministic and full account digits are not exposed.

**Verification:**

- [x] Focused contract tests pass.
- [x] macOS app and test targets compile.

**Dependencies:** None

**Files likely touched:**

- `MonMon/Imports/BankStatementParsing.swift`
- `MonMonTests/Imports/BankStatementParsingTests.swift`
- `MonMon.xcodeproj/project.pbxproj`

**Estimated scope:** Medium, 3 files

## Checkpoint: Contract

- [x] Contract tests pass.
- [x] Existing tests still pass.
- [x] No production parser logic exists without a failing-first test.

## Task 2: Recognize TPBank PDF and parse safe statement metadata

**Description:** Add a synthetic PDF fixture builder and the smallest TPBank
adapter that validates PDF state, recognizes the bilingual format, and returns
period, VND currency, bank identity, and only the last four account digits.

**Acceptance criteria:**

- [x] Recognition depends on headings and required columns, not filename.
- [x] Period and safe account metadata parse from a synthetic statement.
- [x] Empty, image-only, encrypted, and unrelated PDFs return documented errors.

**Verification:**

- [x] Focused TPBank parser tests pass.
- [x] App and test targets compile for macOS.

**Dependencies:** Task 1

**Files likely touched:**

- `MonMon/Imports/TPBankPDFStatementParser.swift`
- `MonMonTests/Imports/TPBankPDFTestFixture.swift`
- `MonMonTests/Imports/TPBankPDFStatementParserTests.swift`
- `MonMon.xcodeproj/project.pbxproj`

**Estimated scope:** Medium, 4 files

## Task 3: Parse visual transaction rows and wrapped explanations

**Description:** Extract date, reference, explanation, debit, and credit using
page-space column bounds. Cover both directions, VND grouping separators, row
ordering, and multi-line explanations with failing tests first.

**Acceptance criteria:**

- [x] Each valid visual row returns exact time, reference, note, kind, and
      positive amount.
- [x] Exactly one of debit or credit must be populated.
- [x] Wrapped notes stay with their row and output order matches the statement.

**Verification:**

- [x] Focused one-page parser tests pass.
- [x] Existing contract tests remain green.

**Dependencies:** Task 2

**Files likely touched:**

- `MonMon/Imports/TPBankPDFStatementParser.swift`
- `MonMonTests/Imports/TPBankPDFStatementParserTests.swift`
- `MonMonTests/Imports/TPBankPDFTestFixture.swift`

**Estimated scope:** Medium, 3 files

## Task 4: Reconcile multi-page statements and expose uncertainty

**Description:** Assemble rows across pages, skip structural headers and
footers, parse declared totals, compute exact parsed totals, and return issues
for ambiguous rows or mismatches without silently dropping data.

**Acceptance criteria:**

- [x] Repeated headers and footers never become candidates.
- [x] Three-page candidates retain statement order and deterministic ids.
- [x] Any invalid row or totals mismatch makes `isComplete` false with a
      specific issue.

**Verification:**

- [x] Focused multi-page, totals, determinism, and error tests pass.
- [x] Full macOS test suite passes.

**Dependencies:** Task 3

**Files likely touched:**

- `MonMon/Imports/TPBankPDFStatementParser.swift`
- `MonMonTests/Imports/TPBankPDFStatementParserTests.swift`
- `MonMonTests/Imports/TPBankPDFTestFixture.swift`

**Estimated scope:** Medium, 3 files

## Checkpoint: Parser

- [x] All parser and existing tests pass.
- [x] Synthetic statements exercise multi-page and wrapped-row behavior.
- [x] No row is guessed or silently omitted.

## Task 5: Validate the real format locally and clear quality gates

**Description:** Run a local, uncommitted harness against the supplied TPBank
PDF without printing its content. Fix only parser defects exposed by that run,
then clear the repository's completion gates and document any discovered layout
constraint in the spec.

**Acceptance criteria:**

- [x] The supplied file is recognized and returns a complete, totals-reconciled result without logging source text.
- [x] No real PDF, preview, extracted text, or derived real-data fixture appears in the worktree.
- [x] Any newly discovered layout rule is recorded before implementation relies on it.

**Verification:**

- [x] Full macOS tests pass using the repository command.
- [x] Swift format lint passes.
- [x] Non-Simulator iPhone SDK build passes.
- [x] `scripts/run-iphone.sh Yushaku` reports successful build, install, and launch.
- [x] `git diff --check` passes and the worktree contains no PDF.

**Dependencies:** Task 4

**Files likely touched:**

- `MonMon/Imports/TPBankPDFStatementParser.swift`
- `MonMonTests/Imports/TPBankPDFStatementParserTests.swift`
- `SPEC-bank-statement-parser.md` only if the observed layout changes the spec

**Estimated scope:** Medium, up to 3 files

## Checkpoint: Complete

- [x] Approved spec success criteria are met.
- [x] Definition of Done is satisfied.
- [x] Human review approves the parser before `statement-share-intake` begins.

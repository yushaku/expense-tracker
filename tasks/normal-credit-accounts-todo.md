# Tasks: Normal and Credit Accounts

## Task 1: Establish the compatible account contract

- [x] Write failing tests for Normal/Credit cases, legacy raw-value decoding,
      credit-limit validation, and persistence.
- [x] Add canonical Normal/Credit encoding, temporary Cash/Bank source aliases, and
      the additive zero-default credit-limit field.
- [x] Extend `AccountDraft` so Credit requires a valid non-negative limit and
      Normal always persists zero.
- [x] Run focused account tests and the repository quality gates.

Files: `CashAccountKind.swift`, `CashAccount.swift`, `AccountDraft.swift`,
`AccountDraftTests.swift`, `CashAccountPersistenceTests.swift`.

## Task 2: Present available credit end to end

- [ ] Write a failing pure test for available-credit arithmetic and edge cases.
- [ ] Add the conditional credit-limit editor field with validation copy and
      accessibility identifiers.
- [ ] Show current balance and derived available credit on Credit account cards;
      leave Normal cards on the existing available-balance presentation.
- [ ] Run focused account tests, format lint for touched files, and commit.

Files: `CashBalanceSummary.swift`, `CashBalanceSummaryTests.swift`,
`AccountEditorForm.swift`, `CashAccountCard.swift`, `Localizable.xcstrings`.

## Checkpoint: Account behavior

- [ ] Focused account suites pass.
- [ ] Normal and Credit presentation compiles against the existing design system.

## Task 3: Preserve backup compatibility

- [ ] Write failing tests for restoring an old account record without a credit
      limit and round-tripping a new Credit limit.
- [ ] Export, validate, create, and update the optional backup credit-limit field;
      validate it as non-negative when present.
- [ ] Prove legacy `cash`/`bank` backup kinds restore as Normal and new exports use
      `normal`.
- [ ] Run focused backup tests and commit.

Files: `MonMonBackupDocument.swift`, `MonMonBackupService.swift`,
`MonMonBackupValidator.swift`, `MonMonBackupDocumentTests.swift`,
`MonMonBackupServiceTests.swift`.

## Task 4: Convert production account-kind consumers

- [ ] Replace typed Cash/Bank production and preview references with Normal without
      changing unrelated asset-allocation `.cash` cases.
- [ ] Update seed/default-account matching and capture behavior to the canonical
      Normal kind.
- [ ] Compile and run relevant seed, transaction, and account tests; commit.

Files are split into reviewable groups across Accounts, Transactions, Savings,
Funds, and Transfers; no group exceeds five files.

## Task 5: Convert test fixtures by domain

- [ ] Convert Accounts/Transactions/App fixtures and run their focused suites.
- [ ] Convert Savings/Funds fixtures and run their focused suites.
- [ ] Convert Debts/Transfers/Imports/Backup/Recurring fixtures and run their
      focused suites.
- [ ] Commit each domain group after its focused verification.

Each domain group is limited to five files where practical; mechanical fixture
files may be grouped only when they share the same compile-only kind replacement.

## Task 6: Remove migration adapters and finish verification

- [ ] Prove repository source has no CashAccountKind Cash/Bank consumers or stale
      Cash/Bank account-type UI copy, then remove temporary aliases.
- [ ] Run code-quality and simplification review; make only scoped corrections.
- [ ] Run full macOS tests, recursive format lint, macOS build, and generic iOS
      device build.
- [ ] Review the staged diff for owner data, secrets, generated output, and unrelated
      edits; commit and report the branch without merging, pushing, or installing.

Files: `CashAccountKind.swift`, spec/plan/task status, plus review-only corrections.

# Implementation Plan: TPBank PDF Statement Parser

## Overview

Implement only the approved `bank-statement-parser` module. The increment reads
TPBank text-based PDF bytes locally and returns deterministic transaction
candidates plus explicit issues. It does not add a Share Extension, UI,
persistence, duplicate detection, categories, or transfer matching.

## Dependency Graph

```text
Typed parser contract and normalization
    |
    v
TPBank document recognition and metadata
    |
    v
Coordinate-based transaction row extraction
    |
    v
Multi-page assembly and totals reconciliation
    |
    v
Quality gates and local real-format validation
```

The tasks are sequential because each slice extends the same contract, parser,
and test fixture. No parallel work is planned.

## Architecture Decisions

- The parser is a pure, synchronous boundary from `Data` to
  `ParsedBankStatement`; it has no storage, UI, or network dependency.
- TPBank detection uses document headings and table columns, never filenames.
- PDFKit page-space selections and relative column bounds are authoritative;
  `PDFPage.string` is not used as the table parser because its reading order can
  differ from visual row order.
- Amounts remain positive `Decimal` values and `TransactionKind` carries
  direction, matching existing transaction models.
- Document-level failures throw a closed error enum. Row-level uncertainty is
  returned as issues so no readable row disappears silently.
- Candidate identity is deterministic across repeated parsing but remains an
  import-layer identifier, not a SwiftData identity.
- Synthetic in-memory PDFs contain only fake values. The real statement stays
  outside Git and is read only by an uncommitted local validation harness.

## Task List

### Phase 1: Contract foundation

- [x] Task 1: Define parser contract and normalization primitives

### Checkpoint: Contract

- [x] Contract tests pass before PDFKit parsing begins.
- [x] App and test targets compile with the new Imports groups.

### Phase 2: TPBank vertical slices

- [x] Task 2: Recognize TPBank PDF and parse safe statement metadata
- [x] Task 3: Parse visual transaction rows and wrapped explanations
- [x] Task 4: Reconcile multi-page statements and expose uncertainty

### Checkpoint: Parser

- [x] Synthetic one-page and three-page fixtures pass.
- [x] Debit/credit totals reconcile exactly with `Decimal`.
- [x] Error and issue paths prove that rows are never guessed or silently lost.

### Phase 3: Completion gates

- [x] Task 5: Validate the real format locally and clear repository quality gates

### Checkpoint: Complete

- [x] Approved spec success criteria are met.
- [x] Full tests and format lint pass.
- [x] Non-Simulator build passes.
- [x] Build, install, and launch on physical iPhone `Yushaku` succeed.
- [x] No real statement data, generated preview, debug output, or PDF exists in
      the repository.
- [x] Human reviews the completed parser before the next module begins.

## Risks and Mitigations

| Risk | Impact | Mitigation |
|---|---|---|
| PDFKit returns content in a different logical order from the visible table | High | Use selection bounds and relative column geometry; cover the page-2 style ordering in synthetic tests. |
| A wrapped explanation is attached to the next transaction | High | Start rows only at a strict date-time cell and merge continuation lines within the table bounds until the next dated row. |
| A debit is interpreted as credit or vice versa | High | Read each amount from its coordinate-defined column and require exactly one populated amount column. |
| A row is skipped while the parser still reports success | High | Reconcile exact parsed debit/credit totals with the declared footer and keep `isComplete` false on any issue. |
| Synthetic fixtures drift from the real TPBank layout | Medium | Generate multiple coordinate variants and perform a local, uncommitted validation against the supplied file. |
| Sensitive statement data enters logs or Git | High | Never log extracted text; use fake fixtures; check the worktree for PDFs and known real values before completion. |
| Manual Xcode project edits omit a source or test file | Medium | Add groups and build-phase entries in the first task, then compile at every checkpoint. |
| PDFKit behavior differs between macOS tests and iOS | Medium | Keep parsing based on documented page coordinates, build both SDKs, and perform the required physical-device launch check. Actual file sharing is validated in `statement-share-intake`. |

## Verification Strategy

- Every behavior change begins with a failing Swift Testing case.
- Run focused parser tests while iterating, then the full macOS suite at each
  checkpoint.
- Run `swift format lint`, the iPhone SDK build without a Simulator runtime, and
  `scripts/run-iphone.sh Yushaku` before declaring the module complete.
- Runtime/UI acceptance of sharing the actual PDF is intentionally deferred to
  `statement-share-intake`; this module has no UI entry point.

## Open Questions

- None. New TPBank layout variants update the approved spec before support is
  broadened.

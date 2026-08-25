# Implementation Plan: Transaction Import Inbox — Review Checkpoint

## Overview

Implement the approved review-only checkpoint of `transaction-import-inbox`.
MonMon will surface PDFs already staged by the Share Extension, parse a selected
TPBank statement locally, show its metadata/candidates/issues, and remove a
statement only after explicit confirmation. No SwiftData record is created.

The previous `statement-share-intake` checkpoint is physically verified: MonMon
appears in the share sheet and the owner successfully staged a PDF on `Yushaku`.

## Dependency Graph

```text
App Group composition + inbox service + contract tests
    |
    v
Main-actor inbox state + state-transition tests
    |
    v
Inbox list + parsed preview UI
    |
    v
Spending banner/toolbar entry + active-scene refresh
    |
    v
Automated gates + physical build/install/launch on Yushaku
```

`import-reconciliation` remains a downstream prerequisite for row editing,
duplicate detection, transfer matching, and commit. This plan does not absorb or
silently bypass that module.

## Architecture Decisions

- Reuse `StatementIntakeStore` as the only reader/remover of staged bytes; UI
  code never constructs inbox paths or reads PDFs directly.
- Add a small `StatementImportInboxService` that composes the store with
  `TPBankPDFStatementParser`. Its live factory resolves the App Group; tests
  inject a temporary root and parser double.
- Move the App Group identifier to one shared configuration constant used by the
  containing app and Share Extension, eliminating configuration drift without
  moving parsing into the extension.
- Parse asynchronously outside the main actor. An observable main-actor state
  type owns explicit list and preview phases and rejects stale async results by
  staged statement id.
- Present Import Inbox as a sheet from Spending. Keep an always-visible toolbar
  entry, plus a high-salience banner only when pending statements exist.
- Refresh pending state when Spending first appears, when the app becomes
  active, and after a removal. A lookup error is a visible error state, never an
  empty count.
- Keep parsed output ephemeral. Reopening a statement parses its revalidated
  stored bytes again; there is no import-session persistence or schema change.
- Map typed intake/parser failures to localized, content-free messages. Never
  interpolate local paths, content hashes, notes, or references into errors.

## Task List

### Phase 1: Inbox domain boundary

- [x] Task 1: Add shared App Group configuration and the inbox service with
      failing-first contract tests

### Checkpoint: Service

- [x] Pending items list in intake-store order.
- [x] Preview revalidates bytes and returns the parser result for the selected id.
- [x] Removal affects only the selected item.
- [x] App Group and parser failures remain typed and content-free.

### Phase 2: Observable inbox state

- [x] Task 2: Add explicit list/preview phases, refresh/removal behavior, and
      stale-result protection with failing-first state tests

### Checkpoint: State

- [x] Empty, loading, loaded, and failed states are distinguishable.
- [x] A slow parse cannot overwrite a newer selection.
- [x] Viewing, retrying, and failing do not delete staged data.

### Phase 3: Owner-facing review flow

- [x] Task 3: Build the accessible inbox list and statement preview screens
- [x] Task 4: Integrate the pending banner, toolbar entry, scene-active refresh,
      and English/Vietnamese strings into Spending

### Checkpoint: UI

- [x] The already-staged PDF is discoverable from Spending.
- [x] Supported metadata, totals, candidates, and issues are visibly distinct.
- [x] Parse failures remain actionable; confirmed removal returns to the updated
      list.
- [x] No import/commit control or SwiftData mutation is present.

### Phase 4: Completion gates

- [ ] Task 5: Run all automated gates and build/install/launch on `Yushaku`

### Checkpoint: Complete

- [ ] Approved spec success criteria are met.
- [x] Full macOS tests and recursive format lint pass.
- [x] Compile-only iOS SDK build passes without using a Simulator runtime.
- [ ] Physical build, install, and launch succeed on `Yushaku`.
- [ ] Owner performs hands-on inbox/preview/removal acceptance testing.
- [ ] No real PDF, extracted statement content, local path, or generated output
      exists in the repository.

## Risks and Mitigations

| Risk | Impact | Mitigation |
|---|---|---|
| App and extension resolve different App Groups | High | Use one shared identifier constant and keep entitlement values unchanged. |
| A 90-day PDF blocks the UI | High | Read and parse off the main actor; publish only state changes on it. |
| An older parse completes after a newer selection | High | Associate each task/result with the selected staged id and discard stale results. |
| Parser failure makes a staged file disappear | High | List from manifests independently; show per-item failure and delete only by confirmed action. |
| Foregrounding shows a stale zero count | Medium | Refresh on initial task and every active scene-phase transition. |
| Raw financial text leaks through diagnostics | High | Closed error mapping; no raw error interpolation, logging, analytics, or path display. |
| Toolbar becomes crowded beside the date filter | Medium | Use one compact tray control and put the explanatory call-to-action in the conditional banner. |
| Review UI implies transactions were imported | High | Use “Review” language, show pending status, and provide no save/import/commit action. |

## Verification Strategy

- Follow TDD for service and state logic: add one failing behavior test, make it
  pass minimally, then refactor while green.
- Reuse temporary-directory intake fixtures and synthetic parser output. Never
  use `/Users/sonlv/Downloads/Trich_dan_sao_ke.pdf` in automated tests.
- Run focused import tests after Tasks 1 and 2.
- Build the iOS target after project membership and again after UI integration.
- Run full macOS tests, recursive format lint, and compile-only iOS SDK build
  before physical deployment.
- Run `rtk scripts/run-iphone.sh Yushaku` only for physical runtime validation.
  Report build/install/launch success; the owner performs UI acceptance.

## Review Checklist

- [x] Scope matches the approved review-only spec.
- [x] New abstractions are justified by entitlement and async-test seams.
- [x] Accessibility labels do not rely on color or icon meaning alone.
- [x] Error messages contain no statement-derived values.
- [x] No unrelated transaction, parser, or storage behavior changed.
- [x] `import-reconciliation` is still required before commit controls.

## Open Questions

None. Implementation starts only after this plan is approved.

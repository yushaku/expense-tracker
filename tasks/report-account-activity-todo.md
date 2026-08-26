# Tasks: Report monthly overview and account activity

## Task 1: Aggregate monthly expense by account

- [x] Cover expense-only totals, zero-spend omission, descending totals, and
      deterministic ties with unit tests.
- [x] Add a pure account-spending summary using the already-selected monthly
      transactions.
- [x] Verify focused summary tests on `Yushaku`.

## Task 2: Build account activity ordering

- [x] Cover account income/expense plus incoming and
      outgoing transfers while excluding unrelated records.
- [x] Add one newest-first activity projection with a stable tie-break.
- [x] Verify focused activity and transfer tests on `Yushaku`.

## Checkpoint: Foundation

- [x] New account summary and activity tests pass on `Yushaku` (4/4).
- [x] Domain files import no SwiftUI.

## Task 3: Integrate Report and account detail UI

- [x] Give Report an independent current-month summary selection controlled by
      the month rail.
- [x] Add the monthly spending-by-account section and navigation.
- [x] Add the read-only all-time account activity screen.
- [x] Preserve report query/search behavior and accessible empty states.

## Task 4: Verify and commit

- [x] Run focused unit tests on `Yushaku` (4/4); the full macOS suite remains
      blocked by the existing `ShortcutsLink` compile error in `SettingsView`.
- [x] Run recursive Swift format lint and diff checks.
- [x] Review correctness, simplicity, accessibility, security, and performance.
- [x] Commit to `feat/report-income-overview`; do not push or merge.
- [x] Build, install, and launch on `Yushaku` only after the owner explicitly
      requested it.

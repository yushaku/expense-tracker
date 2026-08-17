# Feature: Recurring Transactions (Phase 1.5)

Recurring rules generate ordinary domain commands; generated transactions and ledger entries are not a separate accounting path.

## Rule model

Store template type/amount/category/wallet, frequency, interval, anchor local date, original day-of-month, month-end policy, IANA timezone, next due local date, optional end/count, catch-up policy, status, and common timestamps. Monetary values are integer minor units.

Occurrence ID is deterministic UUID v5 from `(ruleId, dueLocalDate, templateVersion)`. Enforce `UNIQUE(rule_id, due_local_date)` and use the same stable `clientRequestId` for the generated financial command.

## Scheduling

On app foreground/start and after rule changes, enumerate every due local date from `nextDue` through today/end. Apply the user’s catch-up policy (`all`, `latest_only`, or `ask`) with a visible preview; cap one batch and continue via cursor so long absences cannot freeze the UI.

Monthly rule behavior is explicit:

- `clamp`: day 29/30/31 becomes the last valid day, but the original desired day is retained for later months.
- `last_day`: always use calendar month end.
- Yearly Feb 29 follows the selected clamp/skip policy.

Compute dates in the rule timezone, then store the resulting UTC instant and offset. DST does not duplicate or omit a local due date.

## Update and missed periods

Rule edits create a template version and affect only ungenerated occurrences. Existing transactions remain historical. Pausing stops generation without moving the schedule; resume previews missed periods. Generation commits the occurrence marker and transaction atomically.

Acceptance covers crash/retry, concurrent devices, long catch-up, pause/resume, timezone/DST, 29/30/31, leap years, template edits, end dates, voided generated transactions, and backup/sync replay.

# Feature: Income and Expenses

## Model and input

An expense/income requires `walletId`, positive `amountMinor`, `currency`, category/source, `occurredAtUtc`, `occurredOffsetMinutes`, status, `isSample`, and common timestamps. Optional merchant/note fields are bounded. A receipt reference is `receiptAssetId`, never a file path.

Vietnamese UI accepts localized decimal text, then `packages/domain` converts it exactly to integer minor units using the currency scale. Floats and JS `number` are rejected at domain/JSON boundaries. Categories are FK-backed stable rows; defaults include Vietnamese labels and can be archived, not deleted while referenced.

## Operations

- Create posts the source, ledger entry, immutable operation, and idempotency result atomically.
- Update amount/category/date/note/merchant through an immutable update command. Changing wallet/currency uses void-and-recreate.
- Void marks source and ledger effects voided while retaining history.
- Search uses `(occurredAtUtc, id)` cursor pagination and bounded wallet/category/status/date/text filters.

Every write has an operation name and `clientRequestId`; same canonical payload returns the stored result, a different payload returns conflict. Financial idempotency records do not expire.

## Acceptance

- Exact min/max currency values round-trip without precision loss or overflow.
- Retry/relaunch cannot duplicate a transaction; void/update retry is also safe.
- Voided records do not affect balance, cash flow, budgets, or dashboard.
- Timestamp display respects stored offset while ordering by UTC instant.
- Receipt loss/failure does not corrupt the financial record and backup/sync includes the managed asset.

MCP add/update/void tools are Phase 3, require `walletId`, `clientRequestId`, and accept `dryRun`.

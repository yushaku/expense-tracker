# Feature: Investments (Phase 1.5)

Investments track manually entered assets; they are not wallets and do not create cash ledger effects unless a separate purchase/sale transaction is recorded.

Fields include ID, type/name, currency, `costBasisMinor`, `currentValueMinor`, `quantityAtomic`, `quantityScale`, valuation/purchase UTC instants and offsets, status, source/note, and common timestamps. Money uses integer minor units. Quantity uses scaled integers/decimal strings—never floating point.

```text
gainMinor = currentValueMinor - costBasisMinor
gainBasisPoints = costBasisMinor == 0 ? null
                : gainMinor * 10_000 / costBasisMinor
```

Net worth includes the latest active current value exactly once. Phase 2 conversion uses immutable exchange-rate snapshots with source/time. Stale or manually entered prices are visibly labeled; no claim of live pricing is made.

Acceptance covers integer/scaled round-trip, zero basis, negative gain, huge values/overflow, valuation ordering, archive/void, backup/restore, sync conflicts, and dashboard reconciliation. Phase 3 MCP changes use durable idempotency, dry-run, read-only policy, and audit.

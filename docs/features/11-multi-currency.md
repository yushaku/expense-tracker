# Feature: Multi-Currency (Phase 2)

Phase 1 launches with VND and still stores a currency on every wallet/transaction. Phase 2 enables additional ISO 4217 currencies and reporting conversion.

Money remains integer minor units with currency-specific scale. Exchange rates are exact rational/scaled values (`numerator`, `denominator`) plus base/quote, source, observed UTC instant/offset, and timestamps; rates are never JS/SQL floats.

Each converted transaction/report stores or references an immutable rate snapshot. Conversion uses documented integer rounding (half-even at the target currency scale) and records any rounding remainder where conservation requires it.

Wallet entries must match wallet currency. Cross-currency transfers create a linked conversion operation with source amount, destination amount, snapshot, fees, and balanced per-currency legs; no fake 1:1 ledger transfer is allowed.

UI always displays currency codes/symbols, source amount, reporting amount, rate source/time, and stale/missing-rate state. Net worth does not silently omit or assume a rate.

Acceptance covers zero/three-decimal currencies, inverse pairs, rounding boundaries, negative gains, stale/missing rates, overflow, offline snapshot reuse, cross-currency conservation, backup, and multi-device convergence.

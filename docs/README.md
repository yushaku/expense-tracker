# Expense Tracker Documentation v3

> Tài liệu chuẩn cho ứng dụng quản lý chi tiêu cá nhân iPhone-first.

## Roadmap

| Phase | Deliverable                                           | Explicit exclusions               |
| ----- | ----------------------------------------------------- | --------------------------------- |
| 1     | iPhone Expo app + local SQLite                        | Mac, Web, Electron, MCP, CloudKit |
| 1.5   | Budget, investment, recurring, native OCR on iPhone   | sync, Mac, MCP                    |
| 2     | CloudKit sync + Mac Expo Web wrapper + multi-currency | Electron, MCP, family             |
| 3     | Mac Electron + local MCP + CKShare family             | custom family backend             |

## Reading order

1. [Product specification](../PRODUCT_SPEC.md) — outcomes, decisions, acceptance, definition of done.
2. `phases/` — release scope and gates.
3. `system/01-data-model.md`, `03-ledger.md` — normative storage and accounting.
4. Remaining `system/` pages — architecture, MCP, CloudKit, security, backup.
5. `features/` — user behavior and feature-specific acceptance criteria.
6. [Review response](REVIEW_RESPONSE.md) — traceability for all 84 findings.

## Non-negotiable conventions

- User-facing text is Vietnamese; technical/code sections are English.
- Monetary values are 64-bit integer minor units; JSON uses decimal strings. Never use JS `number`, SQL `REAL`, or floats for money.
- UTC instants plus timezone offsets are stored for all domain timestamps.
- Every entity has creation/update timestamps; financial records and ledger entries have status.
- Business logic exists once in `packages/domain`.
- Receipts use managed asset IDs, not stored filesystem paths.
- Phase 3 MCP is read-only by default; every write supports dry-run, durable idempotency, and audit.

## Document map

```text
docs/
  phases/   01 Phase 1 · 02 Phase 1.5 · 03 Phase 2 · 04 Phase 3
  system/   data model · architecture · ledger · MCP · CloudKit · security · backup
  features/ wallets · expenses · dashboard · MCP · onboarding · sync
            budget · investment · recurring · OCR · multi-currency · family
```

When documents conflict, the product phase table governs scope; the data model and ledger pages govern persistence/accounting; the stricter security or validation rule wins. Update all affected documents in the same change.

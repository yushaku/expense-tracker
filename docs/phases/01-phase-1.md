# Phase 1 — iPhone MVP

## Goal

Ship one reliable, offline personal expense tracker for iPhone using Expo React Native and one app-local SQLite database.

## In scope

- Vietnamese onboarding and optional sample data marked `isSample`.
- Wallets: cash, bank, e-wallet, credit card.
- Expense, income, atomic transfer, update and void.
- Ledger-derived balances, credit-card debt/available credit, dashboard and transaction search.
- Managed receipt attachment storage without OCR.
- Versioned full JSON backup/restore and CSV convenience export/import.
- Optional Face ID privacy gate, iOS Data Protection, accessibility, tests, migrations.

## Out of scope

Mac, Expo Web, Electron, MCP, CloudKit/iCloud sync, shared database/filesystem promises, family sharing, multi-currency, budgets, investments, recurring generation, and OCR. These belong to later phases.

## Technical baseline

- `apps/iphone`: Expo React Native/Router.
- `packages/domain`: all canonical rules and commands.
- `packages/storage-sqlite`: constrained schema, repositories, migrations.
- Local currency is selected at onboarding and fixed per wallet; Phase 1 launch supports VND.
- Money is integer minor units, JSON decimal strings; timestamps are UTC instant + offset.

## Milestones

1. Schema/migrations, money parser, domain invariants, repositories.
2. Onboarding, wallets, transaction forms, category seeds.
3. Ledger/dashboard/card accounting, update/void and reconciliation.
4. Managed attachments and full backup/restore.
5. Accessibility, privacy, performance, migration and recovery testing.

## Acceptance criteria

- Fresh-install through first expense takes no more than the documented onboarding flow and works offline.
- Relaunch preserves data; all balances match active ledger entries.
- Every transfer commits exactly two conserved legs or rolls back entirely.
- Card purchase/payment tests match `debt = expenses - payments` and `available = limit - debt`.
- All writes survive retry without duplication through the global durable idempotency contract.
- Backup/restore produces the same reconciled entities and asset hashes.
- No Phase 1 bundle or UI contains Mac, Electron, MCP, or CloudKit behavior/reference.

## Definition of done

All Phase 1 acceptance criteria and the global definition of done pass on supported physical iPhones; migration from every Phase 1 prerelease/release fixture is verified; Vietnamese empty/error states and VoiceOver/Dynamic Type checks pass; no critical privacy or data-integrity defect remains.

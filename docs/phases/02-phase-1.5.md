# Phase 1.5 — Planning and Capture

## Goal

Extend the iPhone-only offline app with budgets, investments, deterministic recurring transactions, and native receipt OCR.

## In scope

- Category/wallet budgets with weekly, monthly, and yearly local-calendar periods.
- Investments with integer minor-unit valuation and scaled quantities.
- Recurring income/expense rules, missed-period catch-up, pause/resume, deterministic occurrence IDs.
- Receipt scanning through iOS Vision/VisionKit via an Expo native module; explicit confirmation before creating an expense.
- Full backup/migration support for every new entity and asset.

## Out of scope

Mac clients, CloudKit, Electron, MCP, family sharing, cloud OCR, automatic brokerage feeds, and autonomous AI categorization.

## Acceptance criteria

- Budget totals exclude voided expenses and transfers and respect local period boundaries.
- Investment gain/loss uses exact integer/scaled arithmetic with an explicit valuation timestamp.
- Recurring relaunch/catch-up creates each due occurrence once, including 29/30/31 and leap-year cases.
- OCR uses native Vision/VisionKit, operates on-device, stores a managed asset ID, and never saves without review.
- Phase 1 backups migrate and Phase 1.5 backups round-trip all added state.

## Definition of done

Domain, migration, device, accessibility, backup, calendar/timezone, and OCR permission/failure tests pass on supported iPhones without introducing a network or Mac dependency.

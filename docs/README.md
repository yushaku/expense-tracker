# Expense Tracker — Documentation

> Personal finance management app with AI advisor via MCP

## 📂 Structure

```
docs/
├── README.md           ← Bạn đang đọc
├── phases/
│   01-phase-1.md       ← MVP: iPhone + Mac + local SQLite
│   02-phase-1.5.md     ← Budget + Investment + Recurring + OCR
│   03-phase-2.md       ← CloudKit sync + Mac UI + Multi-currency
│   04-phase-3.md       ← Family sharing
├── features/
│   01-wallets.md       ← Wallet CRUD, Transfer, Opening balance
│   02-expenses.md      ← Expense/Income CRUD, Soft void, Edit
│   03-dashboard.md     ← Cash flow, Category breakdown, Savings rate
│   04-mcp-server.md    ← MCP tools, Resources, Structured errors
│   05-onboarding.md    ← Default wallets, Sample data, First run
│   06-sync.md          ← Export/Import → CloudKit sync
│   07-budget.md        ← Budget CRUD + Alert (Phase 1.5)
│   08-investment.md    ← Investment tracking (Phase 1.5)
│   09-recurring.md     ← Recurring expenses (Phase 1.5)
│   10-ocr.md           ← Receipt scanning (Phase 1.5)
│   11-multi-currency.md ← Multi-currency support (Phase 2)
│   12-family.md        ← Multi-user sharing (Phase 3)
├── system/
│   01-data-model.md    ← Entities, relationships, invariants
│   02-architecture.md  ← High-level system architecture
│   03-ledger.md        ← Ledger engine (balance derivation)
│   04-mcp-protocol.md  ← MCP protocol implementation details
│   05-cloudkit.md      ← CloudKit sync design (Phase 2)
│   06-security.md      ← Auth, encryption, privacy
│   07-backup.md        ← Export/Import, backup/restore
```

---

## 🚀 Quick Start

| Phase | Goal | Status |
|-------|------|--------|
| **Phase 1** | iPhone + Mac, local SQLite, manual entry, basic dashboard, MCP | 📝 Planning |
| **Phase 1.5** | Budget, Investment, Recurring, OCR, export/import | 📝 Planning |
| **Phase 2** | CloudKit sync, Mac Electron, multi-currency | 📝 Planning |
| **Phase 3** | Family sharing, multi-user | 📝 Planning |

---

## 📖 Product Spec

- Full spec: `../PRODUCT_SPEC.md`
- This folder: design documents (feature + system)

---

## 🔧 Tech Stack

| Layer | Tech |
|-------|------|
| Mobile + Desktop | Expo React Native |
| State | Zustand |
| Local DB | expo-file-system + SQLite |
| Sync | Phase 1: None. Phase 2: CloudKit |
| MCP Server | Node.js + TypeScript + better-sqlite3 |
| OCR | Phase 1.5+: Tesseract on-device |
| Notifications | expo-notifications |
| Auth | Phase 1: Face ID / system auth |

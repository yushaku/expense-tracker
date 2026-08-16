# Expense Tracker — Product Spec v2

> Personal finance management app with AI advisor via MCP
> Chạy trên iPhone + MacBook, single-device Phase 1 → CloudKit sync Phase 2

---

## 🎯 Vision

> App nhỏ gọn giúp bạn **biết tiền đi đâu, còn bao nhiêu, nên làm gì tiếp** — manual entry nhanh, AI agent truy cập data trực tiếp qua MCP.

---

## 👤 Target User

| Phase | User | Scope |
|-------|------|-------|
| **Phase 1** | Solo | iPhone + Mac local, expense/income/wallet/thin dashboard |
| **Phase 1.5** | Solo | + Budget, Investment, Recurring, OCR, export/import |
| **Phase 2** | Solo | + CloudKit sync, Mac UI, automation, multi-currency |
| **Phase 3** | Family | + Multi-user, shared budgets |

---

## 🗺️ Feature Roadmap

### Phase 1 — Foundation (MVP)

**Clients:**
- iPhone (Expo React Native) — primary
- Mac (Expo Web wrapper) — secondary, same codebase
- MCP Server (Node.js/TS) — chạy Mac, đọc local SQLite

**Wallets:**
- Cash / Bank / E-wallet / Credit Card (credit limit cho CC)
- Transfer giữa các ví
- Opening balance tạo ledger entry (không set balance trực tiếp)
- `Wallet.balance` derived từ ledger (invariant #1)

**Expense/Income:**
- Manual entry
- Soft void (đánh dấu `voided: true`, giữ trong history, không tính vào metrics)
- Edit/Update (voided record không update được)
- Timezone: `Asia/Ho_Chi_Minh` cố định
- Idempotency key `clientRequestId` cho MCP writes

**Dashboard:**
- Cash flow (thu - chi ròng)
- Category breakdown (%)
- Savings rate (% thu nhập tiết kiệm)
- Wallet balances (derived)

**Monthly report:** cơ bản

**Other:**
- Local auth: Face ID (iPhone), system auth (Mac)
- Onboarding: tạo ví mặc định, danh mục VND, sample data (`isSample` flag)
- Daily reminder notification
- Export CSV / Backup (JSON)
- Custom app icon

### Phase 1.5 — Budget + Investment + Automation

- Budget management + alert (80% warning)
- Recurring expenses (rent, subscription)
- Investment tracking: Gold / Crypto / ETF / Real Estate / Fund / Stock
- Net Worth + Asset Allocation
- OCR receipt scanning
- Export/import polish (Mac migrate)

### Phase 2 — Sync + True Multi-device

- **CloudKit sync** (Apple-only, privacy)
- Mac Electron wrapper nếu cần
- Open banking / Email forwarding
- Multi-currency support

### Phase 3 — Family

- Multi-user, shared budgets, per-person tracking

---

## 🏗️ Architecture

```
┌──────────────────────────────────────────────────────────┐
│                      User Devices                         │
│                                                            │
│  ┌─────────────────┐       ┌─────────────────────────┐   │
│  │    iPhone        │       │       Mac                │   │
│  │  (Expo RN)       │       │  (Expo Web / Electron)   │   │
│  │                  │       │                          │   │
│  │  Local SQLite    │       │  MCP Server (Node.js/TS) │   │
│  │  single-device   │       │  đọc local SQLite        │   │
│  └────────┬─────────┘       └───────────┬──────────────┘   │
│           │                              │                  │
│           │    Export/Import (Phase 1.5) │                  │
│           └──────────┬───────────────────┘                  │
│                      │                                      │
│           Phase 2: CloudKit sync                            │
│                      │                                      │
└──────────────────────┼──────────────────────────────────────┘
                       │
                       ▼
              ┌─────────────────┐
              │   CloudKit       │
              │   (Apple-only)   │
              └─────────────────┘
```

**Phase 1 note:** MCP gắn 1 DB path local; iPhone↔Mac = export/import (Phase 1.5+).

---

## 📊 Data Model

### Expense

```
Expense
├── id: string (uuid)
├── amount: number (positive)
├── currency: string (VND only Phase 1)
├── category: enum [food, transport, shopping, entertainment, healthcare, education, bills, savings, other]
├── description: string
├── date: ISO datetime (Asia/Ho_Chi_Minh)
├── walletId: string (FK → Wallet)
├── merchant: string (optional)
├── receiptImage: string (file path, optional)
├── status: enum [active, voided]
├── clientRequestId: string (idempotency key)
├── createdAt: ISO datetime
├── updatedAt: ISO datetime
```

### Income

```
Income
├── id: string (uuid)
├── amount: number (positive)
├── currency: string (VND only Phase 1)
├── source: string (lương / thu nhập phụ / đầu tư)
├── description: string
├── date: ISO datetime (Asia/Ho_Chi_Minh)
├── walletId: string (FK → Wallet)
├── type: enum [salary, freelance, investment, gift, other]
├── status: enum [active, voided]
├── clientRequestId: string (idempotency key)
├── createdAt: ISO datetime
├── updatedAt: ISO datetime
```

### Wallet

```
Wallet
├── id: string (uuid)
├── name: string (Ví tiền mặt, Vietcombank, Momo, ...)
├── type: enum [cash, bank, ewallet, credit_card]
├── balance: DERIVED (không lưu trực tiếp)
├── currency: string (VND only Phase 1)
├── creditLimit: number (cho credit_card)
├── createdAt: ISO datetime
├── updatedAt: ISO datetime
```

### Transfer

```
Transfer
├── id: string (uuid)
├── fromWalletId: string (FK → Wallet)
├── toWalletId: string (FK → Wallet)
├── amount: number
├── currency: string
├── date: ISO datetime
├── note: string
├── status: enum [active, voided]
├── clientRequestId: string (idempotency key)
├── createdAt: ISO datetime
```

### LedgerEntry (internal — không expose qua API)

```
LedgerEntry
├── id: string
├── walletId: string
├── type: enum [expense, income, transfer_out, transfer_in, opening_balance]
├── amount: number (signed)
├── refId: string (FK → Expense/Income/Transfer)
├── refType: enum [expense, income, transfer]
├── date: ISO datetime
```

### Budget (Phase 1.5)

```
Budget
├── id: string (uuid)
├── category: enum [food, transport, shopping, entertainment, healthcare, education, bills, savings, other, all]
├── amount: number
├── currency: string (VND)
├── period: enum [weekly, monthly, yearly]
├── startDate: ISO datetime
├── endDate: ISO datetime | null (null = ongoing)
├── createdAt: ISO datetime
├── updatedAt: ISO datetime
```

### Investment (Phase 1.5)

```
Investment
├── id: string (uuid)
├── name: string (Vàng SJC, Căn hộ Q7, BTC, VTI, ...)
├── type: enum [gold, real_estate, fund, crypto, etf, bond, stock, other]
├── currentValue: number
├── costBasis: number
├── quantity: number
├── unit: string (lượng, BTC, cổ phần, ...)
├── purchaseDate: ISO datetime
├── currency: string (VND)
├── notes: string
├── createdAt: ISO datetime
├── updatedAt: ISO datetime
```

---

## 📊 Metrics

### Phase 1

| Metric | Công thức | Ghi chú |
|--------|-----------|---------|
| Cash flow ròng | Σ(income active) − Σ(expense active) | Loại transfer, voided, opening_balance |
| Savings rate | (Cash flow ròng / Σ(income active)) × 100 | Income = 0 → 0% |
| Category breakdown | % theo danh mục (chỉ expense active) | — |
| Wallet balance | Σ(ledger entries for wallet) | Chỉ tính entry `active` |
| CC debt | Σ(expense CC active) − Σ(transfer to CC) | — |
| CC available | creditLimit − debt | — |

### Phase 1.5

| Metric | Công thức |
|--------|-----------|
| Tổng tài sản ròng | Σ(Wallet balance) + Σ(Investment currentValue) |
| Phân bổ tài sản | % Cash, Gold, Crypto, Real Estate, ETF, v.v. |
| Lợi nhuận đầu tư | Σ(CurrentValue − CostBasis) |
| Budget utilization | % ngân sách đã dùng |

---

## 🔒 Invariants (Critical)

1. **Balance derived:** `Wallet.balance` = Σ(income active to wallet) − Σ(expense active from wallet) + Σ(transfer in active) − Σ(transfer out active) + opening_balance. Không lưu trực tiếp.

2. **CC payment ≠ expense:** `transfer(from=bank, to=cc)` = debt settlement. Spending CC = `add_expense(wallet=cc)`. Không cho `add_expense` kiểu "trả thẻ".

3. **Soft void:** Record giữ nguyên trong history/audit, `status: voided`. Không tính vào balance/metrics. Voided record không update được.

4. **Idempotency:** Cùng `clientRequestId` + cùng payload → return original. Cùng key + khác payload → error `IDEMPOTENCY_CONFLICT`. Dry-run không consume key.

5. **Conservation (transfer):** `amount_out == amount_in`, atomic 2 legs, reject `from == to`.

6. **Metrics hygiene:** Chỉ từ expense+income `active`. Loại transfer, voided, opening_balance. CC spending là expense. CC payment không là expense.

7. **CC balance semantics:** `debt = Σ(expense CC) − Σ(payments CC)`. `available = creditLimit − debt`.

8. **Currency Phase 1:** Mọi ví/giao dịch VND. Reject khác.

9. **Local day:** Bucket theo `Asia/Ho_Chi_Minh` timezone cố định.

10. **Void transfer:** Void cả cặp hoặc reject nếu chưa support.

11. **No negative money:** Không cho expense âm / income âm.

12. **Credit limit:** Hard block — không cho spend quá credit limit.

13. **Income vào CC wallet:** Reject (CC là debt, income vào CC không make sense).

---

## 🤖 MCP Server Design

### Transport

stdio (local) — chạy như CLI tool trên máy.

### Cách dùng

Config block trong Claude Code / Codex / bất kỳ agent nào hỗ trợ MCP:

```json
{
  "mcpServers": {
    "expense-tracker": {
      "command": "node",
      "args": ["/Users/nami/work/expense-tracker/apps/mcp-server/dist/index.js"],
      "env": {
        "EXPENSE_DB_PATH": "~/Library/Application Support/expense-tracker/expenses.db",
        "EXPENSE_MCP_READONLY": "false"
      }
    }
  }
}
```

### Tools Phase 1 (9 tools)

| # | Tool | Mô tả | Params |
|---|------|--------|--------|
| 1 | `add_expense` | Thêm chi tiêu | amount, currency(VND), category, description?, date?, walletId, merchant?, dryRun?, clientRequestId |
| 2 | `update_expense` | Cập nhật chi tiêu | id, amount?, category?, description?, date? |
| 3 | `void_expense` | Soft void chi tiêu | id |
| 4 | `add_income` | Thêm thu nhập | amount, currency(VND), source?, description?, date?, walletId, type?, dryRun?, clientRequestId |
| 5 | `update_income` | Cập nhật thu nhập | id, amount?, source?, description?, date? |
| 6 | `void_income` | Soft void thu nhập | id |
| 7 | `get_wallets` | Xem danh sách ví | — |
| 8 | `transfer` | Transfer giữa ví | fromWalletId, toWalletId, amount, date?, note?, dryRun?, clientRequestId |
| 9 | `search_transactions` | Tìm giao dịch | from?, to?, walletId?, category?, type?, text?, includeVoided?, limit?, offset? |

### Tools Phase 1.5 (thêm)

- `set_budget`, `get_budgets`
- `add_investment`, `get_investments`, `update_investment_value`

### Resources

- `expense://categories` — danh mục chi tiêu
- `expense://wallets` — danh sách ví

### Structured Errors

| Code | Mô tả |
|------|-------|
| `VALIDATION_ERROR` | Input không hợp lệ |
| `NOT_FOUND` | Record không tồn tại |
| `ALREADY_VOIDED` | Record đã void |
| `IDEMPOTENCY_CONFLICT` | clientRequestId conflict |
| `INSUFFICIENT_AVAILABLE_CREDIT` | Vượt credit limit |
| `TRANSFER_SAME_WALLET` | from == to |
| `CURRENCY_UNSUPPORTED` | Không phải VND |
| `DB_UNAVAILABLE` | DB không accessible |

---

## 🔧 Tech Stack

| Layer | Tech | Lý do |
|-------|------|-------|
| Mobile + Desktop | **Expo React Native** | 1 codebase → iOS + macOS Web |
| State | **Zustand** | Nhẹ, đơn giản |
| Local DB | **expo-file-system + SQLite** | Ghi trực tiếp file |
| Sync | **Phase 1:** None. **Phase 2:** CloudKit | Apple-only, privacy |
| MCP Server | **Node.js + TypeScript** | `@modelcontextprotocol/sdk` |
| Server DB | **better-sqlite3** | SQLite native, nhanh |
| OCR | **Phase 1.5+:** Tesseract on-device | Không gửi data ra ngoài |
| Notifications | **expo-notifications** | Native push |
| Auth | **Phase 1:** Face ID / system auth | Local only |

---

## ✅ MVP Checklist — Phase 1

```
[ ]  Setup monorepo (npm workspaces)
[ ]  Shared types (Expense, Income, Wallet, Transfer)
[ ]  Mobile scaffold (Expo Router, iPhone + Mac)
[ ]  Local SQLite + ledger logic
[ ]  Manual expense entry UI
[ ]  Manual income entry UI
[ ]  Wallet management UI (Cash / Bank / E-wallet / Credit Card)
[ ]  Transfer between wallets UI
[ ]  Soft void + Edit UI
[ ]  Onboarding (default wallets, VND categories, sample data)
[ ]  Dashboard: Cash flow + Category % + Savings rate + Wallet balances
[ ]  Monthly report (basic)
[ ]  Daily reminder notification
[ ]  Local auth (Face ID / system auth)
[ ]  Export CSV / Backup JSON
[ ]  MCP Server: 9 tools + Resources + Structured errors
[ ]  MCP dry-run + idempotency
[ ]  EXPENSE_MCP_READONLY env support
[ ]  Custom app icon
[ ]  MCP config block cho Claude Code / Codex
```

## ✅ Checklist — Phase 1.5

```
[ ]  Budget CRUD + alert (80%)
[ ]  Recurring expenses
[ ]  Investment CRUD (Gold / Crypto / ETF / Real Estate / Fund / Stock)
[ ]  Net Worth + Asset Allocation UI
[ ]  OCR receipt scanning
[ ]  Export/import polish
[ ]  MCP tools: set_budget, get_budgets, add_investment, get_investments
```

## ✅ Checklist — Phase 2

```
[ ]  CloudKit sync
[ ]  Mac Electron wrapper
[ ]  Open banking / Email forwarding
[ ]  Multi-currency support
```

---

## ❓ Đóng Spec — Không còn open questions

| # | Câu hỏi | Quyết định |
|---|---------|------------|
| 1 | Phase 1 primary client | iPhone + Mac UI (same codebase) |
| 2 | OCR | Cắt khỏi Phase 1, sang 1.5 |
| 3 | Credit card | Phase 1, transfer = debt settlement |
| 4 | Transfer giữa ví | Phase 1, atomic 2 legs |
| 5 | Sync Phase 2 | CloudKit |
| 6 | Recurring | Phase 1.5 |
| 7 | MCP tool count | 9 tools |
| 8 | List/search tool | `search_transactions` bắt buộc |
| 9 | Opening balance | Ledger entry |
| 10 | MCP single-device | Ghi rõ export/import 1.5+ |
| 11 | Void transfer | Void cả cặp hoặc reject |
| 12 | Over-limit | Hard block |
| 13 | Income vào CC | Reject |
| 14 | Savings category | Transfer vào ví savings |
| 15 | Sample data | `isSample` flag |
| 16 | Timezone | Asia/Ho_Chi_Minh cố định |
| 17 | Currency | VND only Phase 1 |
| 18 | Placeholder env vars | EXPENSE_DB_PATH, EXPENSE_MCP_READONLY |

# Feature: Onboarding

> Default wallets, Sample data, First run

---

## Overview

Guide new users through initial setup, create default wallets and categories, and optionally seed sample data.

## Onboarding Flow

### Step 1: Welcome
- Brief intro: "Quản lý chi tiêu cá nhân của bạn"
- Single button: "Bắt đầu"

### Step 2: Default Wallets
- Pre-create 3 wallets:
  - Ví tiền mặt (Cash)
  - Tài khoản ngân hàng (Bank)
  - Ví điện tử (E-wallet)
- User can rename or skip

### Step 3: Opening Balance
- For each wallet, optionally set opening balance
- Default: 0
- Creates `opening_balance` ledger entry

### Step 4: Categories
- Show default VND categories
- User can add custom categories (Phase 1.5+)
- Default: food, transport, shopping, entertainment, healthcare, education, bills, savings, other

### Step 5: Daily Reminder
- Ask to enable daily reminder notification
- Default time: 21:00
- Message: "Đừng quên ghi nhận chi tiêu hôm nay!"

### Step 6: Sample Data (optional)
- "Thêm dữ liệu mẫu để thử nghiệm?"
- If yes, seed:
  - 5 sample expenses across categories
  - 1 sample income
  - Mark all with `isSample: true`

## Sample Data

```json
{
  "expenses": [
    { "amount": 50000, "category": "food", "description": "Ăn trưa", "isSample": true },
    { "amount": 15000, "category": "transport", "description": "Grab", "isSample": true },
    { "amount": 200000, "category": "shopping", "description": "Mua sắm", "isSample": true },
    { "amount": 30000, "category": "entertainment", "description": "Xem phim", "isSample": true },
    { "amount": 100000, "category": "bills", "description": "Tiền điện", "isSample": true }
  ],
  "incomes": [
    { "amount": 15000000, "type": "salary", "source": "Lương", "isSample": true }
  ]
}
```

## Wipe Sample Data

- In settings: "Xóa dữ liệu mẫu"
- DELETE all records WHERE `isSample = true`
- Balance recalculates from remaining ledger entries

## UI Screens

- `/onboarding` — welcome + setup wizard
- `/settings` → "Reset sample data"

## Post-Onboarding

- Redirect to home dashboard
- Show empty state with CTA: "Thêm chi tiêu đầu tiên"

// packages/domain/src/database.ts
// In-memory database for testing (SQLite adapter comes later)

export interface LedgerEntry {
  id: string;
  walletId: string;
  sourceType: 'expense' | 'income' | 'transfer' | 'opening_balance' | 'refund';
  sourceId: string;
  entryKind: 'expense' | 'income' | 'transfer_out' | 'transfer_in' | 'opening_balance' | 'refund';
  signedMinor: bigint;
  currency: string;
  status: 'active' | 'voided';
  occurredAtUtc: string;
  createdAtUtc: string;
}

export interface Wallet {
  id: string;
  name: string;
  type: 'cash' | 'bank' | 'ewallet' | 'credit_card';
  currency: string;
  creditLimitMinor: bigint;
  status: 'active' | 'voided';
  createdAtUtc: string;
  updatedAtUtc: string;
}

export interface Expense {
  id: string;
  walletId: string;
  categoryId: string;
  amountMinor: bigint;
  currency: string;
  description?: string;
  merchant?: string;
  occurredAtUtc: string;
  status: 'active' | 'voided';
  isSample: boolean;
  createdAtUtc: string;
  updatedAtUtc: string;
}

export interface Income {
  id: string;
  walletId: string;
  categoryId?: string;
  amountMinor: bigint;
  currency: string;
  source?: string;
  type: 'salary' | 'freelance' | 'investment' | 'gift' | 'other';
  description?: string;
  occurredAtUtc: string;
  status: 'active' | 'voided';
  isSample: boolean;
  createdAtUtc: string;
  updatedAtUtc: string;
}

export interface Category {
  id: string;
  kind: 'expense' | 'income';
  labelVi: string;
  status: 'active' | 'archived';
  isSystem: boolean;
}

export class InMemoryDatabase {
  private wallets: Map<string, Wallet> = new Map();
  private expenses: Map<string, Expense> = new Map();
  private incomes: Map<string, Income> = new Map();
  private categories: Map<string, Category> = new Map();
  private ledger: LedgerEntry[] = [];

  // Wallet operations
  createWallet(w: Wallet): Wallet {
    this.wallets.set(w.id, w);
    return w;
  }

  getWallet(id: string): Wallet | undefined {
    return this.wallets.get(id);
  }

  getAllWallets(): Wallet[] {
    return Array.from(this.wallets.values());
  }

  updateWallet(id: string, updates: Partial<Wallet>): Wallet {
    const wallet = this.wallets.get(id);
    if (!wallet) throw new Error('WALLET_NOT_FOUND');
    const updated = { ...wallet, ...updates, updatedAtUtc: new Date().toISOString() };
    this.wallets.set(id, updated);
    return updated;
  }

  deleteWallet(id: string): void {
    this.wallets.delete(id);
  }

  // Expense operations
  createExpense(e: Expense): Expense {
    this.expenses.set(e.id, e);
    return e;
  }

  getExpense(id: string): Expense | undefined {
    return this.expenses.get(id);
  }

  getAllExpenses(): Expense[] {
    return Array.from(this.expenses.values());
  }

  updateExpense(id: string, updates: Partial<Expense>): Expense {
    const expense = this.expenses.get(id);
    if (!expense) throw new Error('EXPENSE_NOT_FOUND');
    const updated = { ...expense, ...updates, updatedAtUtc: new Date().toISOString() };
    this.expenses.set(id, updated);
    return updated;
  }

  // Income operations
  createIncome(i: Income): Income {
    this.incomes.set(i.id, i);
    return i;
  }

  getIncome(id: string): Income | undefined {
    return this.incomes.get(id);
  }

  getAllIncomes(): Income[] {
    return Array.from(this.incomes.values());
  }

  updateIncome(id: string, updates: Partial<Income>): Income {
    const income = this.incomes.get(id);
    if (!income) throw new Error('INCOME_NOT_FOUND');
    const updated = { ...income, ...updates, updatedAtUtc: new Date().toISOString() };
    this.incomes.set(id, updated);
    return updated;
  }

  // Category operations
  createCategory(c: Category): Category {
    this.categories.set(c.id, c);
    return c;
  }

  getAllCategories(): Category[] {
    return Array.from(this.categories.values());
  }

  // Ledger operations
  createLedgerEntry(entry: LedgerEntry): void {
    this.ledger.push(entry);
  }

  getLedgerEntries(walletId: string): LedgerEntry[] {
    return this.ledger.filter((e) => e.walletId === walletId);
  }

  getAllLedgerEntries(): LedgerEntry[] {
    return [...this.ledger];
  }

  getBalance(walletId: string): bigint {
    return this.ledger
      .filter((e) => e.walletId === walletId && e.status === 'active')
      .reduce((sum, e) => sum + e.signedMinor, 0n);
  }

  // Seed default categories
  seedDefaultCategories(): void {
    const defaults: Category[] = [
      { id: 'cat_food', kind: 'expense', labelVi: 'Ăn uống', status: 'active', isSystem: true },
      {
        id: 'cat_transport',
        kind: 'expense',
        labelVi: 'Di chuyển',
        status: 'active',
        isSystem: true,
      },
      { id: 'cat_shopping', kind: 'expense', labelVi: 'Mua sắm', status: 'active', isSystem: true },
      {
        id: 'cat_entertainment',
        kind: 'expense',
        labelVi: 'Giải trí',
        status: 'active',
        isSystem: true,
      },
      { id: 'cat_healthcare', kind: 'expense', labelVi: 'Y tế', status: 'active', isSystem: true },
      {
        id: 'cat_education',
        kind: 'expense',
        labelVi: 'Giáo dục',
        status: 'active',
        isSystem: true,
      },
      { id: 'cat_bills', kind: 'expense', labelVi: 'Hóa đơn', status: 'active', isSystem: true },
      { id: 'cat_other', kind: 'expense', labelVi: 'Khác', status: 'active', isSystem: true },
    ];
    defaults.forEach((c) => this.categories.set(c.id, c));
  }
}

// Singleton instance for shared use
let sharedDb: InMemoryDatabase | null = null;

export function getSharedDb(): InMemoryDatabase {
  if (!sharedDb) {
    sharedDb = new InMemoryDatabase();
    sharedDb.seedDefaultCategories();
  }
  return sharedDb;
}

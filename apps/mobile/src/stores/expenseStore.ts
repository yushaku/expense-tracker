// apps/mobile/src/stores/expenseStore.ts
// Expense store — CRUD + Soft void + Edit using Zustand

import { create } from 'zustand';
import {
  ExpenseCategory,
  SupportedCurrency,
  Expense,
  AddExpenseInput,
  UpdateExpenseInput,
  VoidByIdInput,
  LedgerEngine,
  Database,
  generateId,
  formatCurrency,
  CATEGORY_LABELS,
} from '@expense/shared';

// Database row types matching @expense/shared
interface ExpenseRow {
  id: string;
  amount: number;
  currency: string;
  category: string;
  description: string;
  date: string;
  walletId: string;
  merchant: string | null;
  receiptImage: string | null;
  status: string;
  clientRequestId: string | null;
  createdAt: string;
  updatedAt: string;
}

interface LedgerEntryRow {
  id: string;
  walletId: string;
  type: string;
  amount: number;
  refId: string;
  refType: string;
  date: string;
  status: string;
}

interface WalletRow {
  id: string;
  name: string;
  type: string;
  currency: string;
  creditLimit: number;
  createdAt: string;
  updatedAt: string;
}

interface IncomeRow {
  id: string;
  amount: number;
  currency: string;
  source: string | null;
  description: string;
  date: string;
  walletId: string;
  type: string | null;
  status: string;
  clientRequestId: string | null;
  createdAt: string;
  updatedAt: string;
}

interface TransferRow {
  id: string;
  fromWalletId: string;
  toWalletId: string;
  amount: number;
  currency: string;
  date: string;
  note: string | null;
  status: string;
  clientRequestId: string | null;
  createdAt: string;
}

// In-memory database for mobile (Phase 1)
class InMemoryDatabase implements Database {
  private wallets: Map<string, WalletRow> = new Map();
  private expenses: Map<string, ExpenseRow> = new Map();
  private incomes: Map<string, IncomeRow> = new Map();
  private transfers: Map<string, TransferRow> = new Map();
  private ledgerEntries: Map<string, LedgerEntryRow> = new Map();
  private budgets: Map<string, any> = new Map();
  private investments: Map<string, any> = new Map();

  createWallet(data: Omit<WalletRow, 'createdAt' | 'updatedAt'>): WalletRow {
    const now = new Date().toISOString();
    const wallet = { ...data, createdAt: now, updatedAt: now };
    this.wallets.set(data.id, wallet);
    return wallet;
  }

  getWallet(id: string): WalletRow | null {
    return this.wallets.get(id) ?? null;
  }

  getAllWallets(): WalletRow[] {
    return Array.from(this.wallets.values());
  }

  updateWallet(id: string, updates: Partial<WalletRow>): WalletRow {
    const wallet = this.wallets.get(id);
    if (!wallet) throw new Error('NOT_FOUND: wallet not found');
    const updated = { ...wallet, ...updates, updatedAt: new Date().toISOString() };
    this.wallets.set(id, updated);
    return updated;
  }

  deleteWallet(id: string): boolean {
    return this.wallets.delete(id);
  }

  createExpense(data: Omit<ExpenseRow, 'createdAt' | 'updatedAt'>): ExpenseRow {
    const now = new Date().toISOString();
    const expense = { ...data, createdAt: now, updatedAt: now };
    this.expenses.set(data.id, expense);
    return expense;
  }

  getExpense(id: string): ExpenseRow | null {
    return this.expenses.get(id) ?? null;
  }

  getAllExpenses(options?: { limit?: number; offset?: number }) {
    const rows = Array.from(this.expenses.values());
    return { rows, total: rows.length };
  }

  updateExpense(id: string, updates: Partial<ExpenseRow>): ExpenseRow {
    const expense = this.expenses.get(id);
    if (!expense) throw new Error('NOT_FOUND: expense not found');
    const updated = { ...expense, ...updates, updatedAt: new Date().toISOString() };
    this.expenses.set(id, updated);
    return updated;
  }

  deleteExpense(id: string): boolean {
    return this.expenses.delete(id);
  }

  createIncome(data: Omit<IncomeRow, 'createdAt' | 'updatedAt'>): IncomeRow {
    const now = new Date().toISOString();
    const income = { ...data, createdAt: now, updatedAt: now };
    this.incomes.set(data.id, income);
    return income;
  }

  getIncome(id: string): IncomeRow | null {
    return this.incomes.get(id) ?? null;
  }

  getAllIncomes(options?: { limit?: number; offset?: number }) {
    const rows = Array.from(this.incomes.values());
    return { rows, total: rows.length };
  }

  updateIncome(id: string, updates: Partial<IncomeRow>): IncomeRow {
    const income = this.incomes.get(id);
    if (!income) throw new Error('NOT_FOUND: income not found');
    const updated = { ...income, ...updates, updatedAt: new Date().toISOString() };
    this.incomes.set(id, updated);
    return updated;
  }

  deleteIncome(id: string): boolean {
    return this.incomes.delete(id);
  }

  createTransfer(data: Omit<TransferRow, 'createdAt'>): TransferRow {
    const now = new Date().toISOString();
    const transfer = { ...data, createdAt: now };
    this.transfers.set(data.id, transfer);
    return transfer;
  }

  getTransfer(id: string): TransferRow | null {
    return this.transfers.get(id) ?? null;
  }

  getAllTransfers(options?: { limit?: number; offset?: number }) {
    const rows = Array.from(this.transfers.values());
    return { rows, total: rows.length };
  }

  createLedgerEntry(data: LedgerEntryRow): LedgerEntryRow {
    this.ledgerEntries.set(data.id, data);
    return data;
  }

  getLedgerEntries(walletId: string): LedgerEntryRow[] {
    return Array.from(this.ledgerEntries.values()).filter(e => e.walletId === walletId);
  }

  createBudget(data: any): any {
    const now = new Date().toISOString();
    const budget = { ...data, createdAt: now, updatedAt: now };
    this.budgets.set(data.id, budget);
    return budget;
  }

  getAllBudgets(): any[] {
    return Array.from(this.budgets.values());
  }

  updateBudget(id: string, updates: any): any {
    const budget = this.budgets.get(id);
    if (!budget) throw new Error('NOT_FOUND: budget not found');
    const updated = { ...budget, ...updates, updatedAt: new Date().toISOString() };
    this.budgets.set(id, updated);
    return updated;
  }

  deleteBudget(id: string): boolean {
    return this.budgets.delete(id);
  }

  createInvestment(data: any): any {
    const now = new Date().toISOString();
    const investment = { ...data, createdAt: now, updatedAt: now };
    this.investments.set(data.id, investment);
    return investment;
  }

  getAllInvestments(): any[] {
    return Array.from(this.investments.values());
  }

  updateInvestment(id: string, updates: any): any {
    const investment = this.investments.get(id);
    if (!investment) throw new Error('NOT_FOUND: investment not found');
    const updated = { ...investment, ...updates, updatedAt: new Date().toISOString() };
    this.investments.set(id, updated);
    return updated;
  }

  deleteInvestment(id: string): boolean {
    return this.investments.delete(id);
  }

  close(): void {
    // No-op for in-memory
  }

  transaction<T>(fn: () => T): T {
    return fn();
  }
}

// Singleton database instance
let db: InMemoryDatabase | null = null;
let ledger: LedgerEngine | null = null;

function getDb(): Database {
  if (!db) {
    db = new InMemoryDatabase();
    ledger = new LedgerEngine(db);
  }
  return db;
}

function getLedger(): LedgerEngine {
  if (!ledger) {
    getDb();
  }
  return ledger!;
}

export interface ExpenseFilters {
  category?: ExpenseCategory | 'all';
  search?: string;
  startDate?: string;
  endDate?: string;
  status?: 'active' | 'voided' | 'all';
}

interface ExpenseState {
  expenses: Expense[];
  loading: boolean;
  error: string | null;
  filters: ExpenseFilters;

  // Actions
  loadExpenses: () => Promise<void>;
  addExpense: (input: AddExpenseInput) => Promise<Expense>;
  updateExpense: (input: UpdateExpenseInput) => Promise<Expense>;
  voidExpense: (id: string) => Promise<void>;
  getExpenseById: (id: string) => Expense | null;
  setFilters: (filters: ExpenseFilters) => void;
  filteredExpenses: () => Expense[];
}

export const useExpenseStore = create<ExpenseState>((set, get) => ({
  expenses: [],
  loading: false,
  error: null,
  filters: {},

  loadExpenses: async () => {
    set({ loading: true, error: null });
    try {
      const database = getDb();
      const { rows } = database.getAllExpenses();
      const expenses: Expense[] = rows.map((row) => ({
        id: row.id,
        amount: row.amount,
        currency: row.currency as SupportedCurrency,
        category: row.category as ExpenseCategory,
        description: row.description,
        date: row.date,
        walletId: row.walletId,
        merchant: row.merchant ?? undefined,
        receiptImage: row.receiptImage ?? undefined,
        status: row.status as 'active' | 'voided',
        clientRequestId: row.clientRequestId ?? undefined,
        createdAt: row.createdAt,
        updatedAt: row.updatedAt,
      }));
      set({ expenses, loading: false });
    } catch (err: any) {
      set({ loading: false, error: err.message ?? 'Failed to load expenses' });
    }
  },

  addExpense: async (input: AddExpenseInput) => {
    set({ loading: true, error: null });
    try {
      const ledgerEngine = getLedger();
      const row = ledgerEngine.createExpense(input);
      const expense: Expense = {
        id: row.id,
        amount: row.amount,
        currency: row.currency as SupportedCurrency,
        category: row.category as ExpenseCategory,
        description: row.description,
        date: row.date,
        walletId: row.walletId,
        merchant: row.merchant ?? undefined,
        receiptImage: row.receiptImage ?? undefined,
        status: row.status as 'active' | 'voided',
        clientRequestId: row.clientRequestId ?? undefined,
        createdAt: row.createdAt,
        updatedAt: row.updatedAt,
      };
      set((state) => ({
        expenses: [expense, ...state.expenses],
        loading: false,
      }));
      return expense;
    } catch (err: any) {
      set({ loading: false, error: err.message ?? 'Failed to add expense' });
      throw err;
    }
  },

  updateExpense: async (input: UpdateExpenseInput) => {
    set({ loading: true, error: null });
    try {
      const database = getDb();
      const existing = database.getExpense(input.id);
      if (!existing) throw new Error('NOT_FOUND: expense not found');
      if (existing.status === 'voided') throw new Error('ALREADY_VOIDED: cannot update voided expense');

      // Validate amount if provided
      if (input.amount !== undefined && input.amount <= 0) {
        throw new Error('VALIDATION_ERROR: amount must be positive');
      }

      const row = database.updateExpense(input.id, {
        amount: input.amount,
        category: input.category,
        description: input.description,
        date: input.date,
      });

      const expense: Expense = {
        id: row.id,
        amount: row.amount,
        currency: row.currency as SupportedCurrency,
        category: row.category as ExpenseCategory,
        description: row.description,
        date: row.date,
        walletId: row.walletId,
        merchant: row.merchant ?? undefined,
        receiptImage: row.receiptImage ?? undefined,
        status: row.status as 'active' | 'voided',
        clientRequestId: row.clientRequestId ?? undefined,
        createdAt: row.createdAt,
        updatedAt: row.updatedAt,
      };

      set((state) => ({
        expenses: state.expenses.map((e) => (e.id === input.id ? expense : e)),
        loading: false,
      }));
      return expense;
    } catch (err: any) {
      set({ loading: false, error: err.message ?? 'Failed to update expense' });
      throw err;
    }
  },

  voidExpense: async (id: string) => {
    set({ loading: true, error: null });
    try {
      const ledgerEngine = getLedger();
      ledgerEngine.voidExpense(id);

      set((state) => ({
        expenses: state.expenses.map((e) =>
          e.id === id ? { ...e, status: 'voided' as const, updatedAt: new Date().toISOString() } : e
        ),
        loading: false,
      }));
    } catch (err: any) {
      set({ loading: false, error: err.message ?? 'Failed to void expense' });
      throw err;
    }
  },

  getExpenseById: (id: string): Expense | null => {
    const { expenses } = get();
    return expenses.find((e) => e.id === id) ?? null;
  },

  setFilters: (filters: ExpenseFilters) => {
    set({ filters });
  },

  filteredExpenses: (): Expense[] => {
    const { expenses, filters } = get();
    let filtered = [...expenses];

    // Filter by category
    if (filters.category && filters.category !== 'all') {
      filtered = filtered.filter((e) => e.category === filters.category);
    }

    // Filter by search text
    if (filters.search) {
      const searchLower = filters.search.toLowerCase();
      filtered = filtered.filter(
        (e) =>
          e.description.toLowerCase().includes(searchLower) ||
          CATEGORY_LABELS[e.category].toLowerCase().includes(searchLower) ||
          (e.merchant && e.merchant.toLowerCase().includes(searchLower))
      );
    }

    // Filter by date range
    if (filters.startDate) {
      const start = new Date(filters.startDate).getTime();
      filtered = filtered.filter((e) => new Date(e.date).getTime() >= start);
    }
    if (filters.endDate) {
      const end = new Date(filters.endDate).getTime();
      filtered = filtered.filter((e) => new Date(e.date).getTime() <= end);
    }

    // Filter by status
    if (filters.status && filters.status !== 'all') {
      filtered = filtered.filter((e) => e.status === filters.status);
    }

    // Sort by date descending (most recent first)
    filtered.sort((a, b) => new Date(b.date).getTime() - new Date(a.date).getTime());

    return filtered;
  },
}));

export { formatCurrency, CATEGORY_LABELS };
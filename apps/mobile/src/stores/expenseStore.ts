// apps/mobile/src/stores/expenseStore.ts
// Expense store — CRUD + Soft void + Edit using Zustand

import { create } from 'zustand';
import {
  ExpenseCategory,
  SupportedCurrency,
  Expense,
  AddExpenseInput,
  UpdateExpenseInput,
  LedgerEngine,
  generateId,
  formatCurrency,
  CATEGORY_LABELS,
  getSharedDb,
} from '@expense/shared';

// Singleton ledger instance (shares DB with walletStore)
let ledger: LedgerEngine | null = null;

function getLedger(): LedgerEngine {
  if (!ledger) {
    ledger = new LedgerEngine(getSharedDb());
  }
  return ledger;
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
      const database = getSharedDb();
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
      const database = getSharedDb();
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

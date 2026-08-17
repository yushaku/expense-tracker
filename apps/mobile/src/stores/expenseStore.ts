// apps/mobile/src/stores/expenseStore.ts
// Expense store — CRUD + Soft void + Edit using Zustand (v3: @expense/domain)

import { create } from 'zustand';
import { InMemoryDatabase, getSharedDb } from '@expense/domain';

export interface ExpenseViewModel {
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
}

export interface AddExpenseInput {
  walletId: string;
  categoryId: string;
  amountMinor: bigint;
  currency: string;
  description?: string;
  merchant?: string;
  occurredAtUtc?: string;
  clientRequestId?: string;
}

export interface UpdateExpenseInput {
  id: string;
  amountMinor?: bigint;
  categoryId?: string;
  description?: string;
  occurredAtUtc?: string;
}

export interface ExpenseFilters {
  categoryId?: string;
  search?: string;
  startDate?: string;
  endDate?: string;
  status?: 'active' | 'voided' | 'all';
}

interface ExpenseState {
  expenses: ExpenseViewModel[];
  loading: boolean;
  error: string | null;
  filters: ExpenseFilters;

  // Actions
  loadExpenses: () => Promise<void>;
  addExpense: (input: AddExpenseInput) => Promise<ExpenseViewModel>;
  updateExpense: (input: UpdateExpenseInput) => Promise<ExpenseViewModel>;
  voidExpense: (id: string) => Promise<void>;
  getExpenseById: (id: string) => ExpenseViewModel | null;
  setFilters: (filters: ExpenseFilters) => void;
  filteredExpenses: () => ExpenseViewModel[];
}

function mapToViewModel(e: any): ExpenseViewModel {
  return {
    id: e.id,
    walletId: e.walletId,
    categoryId: e.categoryId,
    amountMinor: e.amountMinor,
    currency: e.currency,
    description: e.description,
    merchant: e.merchant,
    occurredAtUtc: e.occurredAtUtc,
    status: e.status,
    isSample: e.isSample,
  };
}

export const useExpenseStore = create<ExpenseState>((set, get) => ({
  expenses: [],
  loading: false,
  error: null,
  filters: {},

  loadExpenses: async () => {
    set({ loading: true, error: null });
    try {
      const db = getSharedDb();
      const allExpenses = db.getAllExpenses();
      const expenses: ExpenseViewModel[] = allExpenses.map(mapToViewModel);
      set({ expenses, loading: false });
    } catch (err: any) {
      set({ loading: false, error: err.message ?? 'Failed to load expenses' });
    }
  },

  addExpense: async (input: AddExpenseInput) => {
    set({ loading: true, error: null });
    try {
      const db = getSharedDb();
      const now = new Date().toISOString();
      const id = crypto.randomUUID();

      const expense = db.createExpense({
        id,
        walletId: input.walletId,
        categoryId: input.categoryId,
        amountMinor: input.amountMinor,
        currency: input.currency,
        description: input.description,
        merchant: input.merchant,
        occurredAtUtc: input.occurredAtUtc ?? now,
        status: 'active',
        isSample: false,
        createdAtUtc: now,
        updatedAtUtc: now,
      } as any);

      // Create ledger entry
      db.createLedgerEntry({
        id: crypto.randomUUID(),
        walletId: input.walletId,
        sourceType: 'expense',
        sourceId: id,
        entryKind: 'expense',
        signedMinor: input.amountMinor,
        currency: input.currency,
        status: 'active',
        occurredAtUtc: input.occurredAtUtc ?? now,
        createdAtUtc: now,
      });

      const expenseVm = mapToViewModel(expense);
      set((state) => ({
        expenses: [expenseVm, ...state.expenses],
        loading: false,
      }));
      return expenseVm;
    } catch (err: any) {
      set({ loading: false, error: err.message ?? 'Failed to add expense' });
      throw err;
    }
  },

  updateExpense: async (input: UpdateExpenseInput) => {
    set({ loading: true, error: null });
    try {
      const db = getSharedDb();
      const existing = db.getExpense(input.id);
      if (!existing) throw new Error('NOT_FOUND: expense not found');
      if (existing.status === 'voided')
        throw new Error('ALREADY_VOIDED: cannot update voided expense');

      if (input.amountMinor !== undefined && input.amountMinor <= 0n) {
        throw new Error('VALIDATION_ERROR: amount must be positive');
      }

      const expense = db.updateExpense(input.id, {
        amountMinor: input.amountMinor,
        categoryId: input.categoryId,
        description: input.description,
        occurredAtUtc: input.occurredAtUtc,
      } as any);

      const expenseVm = mapToViewModel(expense);
      set((state) => ({
        expenses: state.expenses.map((e) => (e.id === input.id ? expenseVm : e)),
        loading: false,
      }));
      return expenseVm;
    } catch (err: any) {
      set({ loading: false, error: err.message ?? 'Failed to update expense' });
      throw err;
    }
  },

  voidExpense: async (id: string) => {
    set({ loading: true, error: null });
    try {
      const db = getSharedDb();
      const existing = db.getExpense(id);
      if (!existing) throw new Error('NOT_FOUND: expense not found');
      if (existing.status === 'voided') throw new Error('ALREADY_VOIDED: expense already voided');

      db.updateExpense(id, { status: 'voided' } as any);

      // Mark ledger entry as voided
      const ledgerEntries = db.getLedgerEntries(existing.walletId);
      ledgerEntries
        .filter((e: any) => e.sourceId === id && e.sourceType === 'expense')
        .forEach((e: any) => {
          e.status = 'voided';
        });

      set((state) => ({
        expenses: state.expenses.map((e) =>
          e.id === id ? { ...e, status: 'voided' as const } : e,
        ),
        loading: false,
      }));
    } catch (err: any) {
      set({ loading: false, error: err.message ?? 'Failed to void expense' });
      throw err;
    }
  },

  getExpenseById: (id: string): ExpenseViewModel | null => {
    const { expenses } = get();
    return expenses.find((e) => e.id === id) ?? null;
  },

  setFilters: (filters: ExpenseFilters) => {
    set({ filters });
  },

  filteredExpenses: (): ExpenseViewModel[] => {
    const { expenses, filters } = get();
    let filtered = [...expenses];

    if (filters.categoryId) {
      filtered = filtered.filter((e) => e.categoryId === filters.categoryId);
    }

    if (filters.search) {
      const searchLower = filters.search.toLowerCase();
      filtered = filtered.filter(
        (e) =>
          (e.description && e.description.toLowerCase().includes(searchLower)) ||
          (e.merchant && e.merchant.toLowerCase().includes(searchLower)),
      );
    }

    if (filters.startDate) {
      filtered = filtered.filter((e) => e.occurredAtUtc >= filters.startDate!);
    }
    if (filters.endDate) {
      filtered = filtered.filter((e) => e.occurredAtUtc <= filters.endDate!);
    }

    if (filters.status && filters.status !== 'all') {
      filtered = filtered.filter((e) => e.status === filters.status);
    }

    filtered.sort((a, b) => b.occurredAtUtc.localeCompare(a.occurredAtUtc));
    return filtered;
  },
}));

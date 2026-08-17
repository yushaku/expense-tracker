// apps/mobile/src/stores/incomeStore.ts
// Income store — CRUD + Soft void + Edit using Zustand

import { create } from 'zustand';
import {
  IncomeType,
  SupportedCurrency,
  Income,
  AddIncomeInput,
  UpdateIncomeInput,
  LedgerEngine,
  generateId,
  formatCurrency,
  getSharedDb,
  getVietnamNow,
} from '@expense/shared';

// Singleton ledger instance (shares DB with walletStore and expenseStore)
let ledger: LedgerEngine | null = null;

function getLedger(): LedgerEngine {
  if (!ledger) {
    ledger = new LedgerEngine(getSharedDb());
  }
  return ledger;
}

// Income type labels (Vietnamese)
export const INCOME_TYPE_LABELS: Record<IncomeType, string> = {
  salary: 'Lương',
  freelance: 'Thu nhập phụ',
  investment: 'Đầu tư',
  gift: 'Quà tặng',
  other: 'Khác',
};

// Income type colors
export const INCOME_TYPE_COLORS: Record<IncomeType, string> = {
  salary: '#3B82F6', // blue
  freelance: '#A855F7', // purple
  investment: '#22C55E', // green
  gift: '#EC4899', // pink
  other: '#64748B', // gray
};

// Income type icons
export const INCOME_TYPE_ICONS: Record<IncomeType, string> = {
  salary: 'briefcase',
  freelance: 'laptop',
  investment: 'chart-line',
  gift: 'gift',
  other: 'dots-horizontal',
};

export interface IncomeFilters {
  type?: IncomeType | 'all';
  search?: string;
  startDate?: string;
  endDate?: string;
  status?: 'active' | 'voided' | 'all';
}

interface IncomeState {
  incomes: Income[];
  loading: boolean;
  error: string | null;
  filters: IncomeFilters;

  // Actions
  loadIncomes: () => Promise<void>;
  addIncome: (input: AddIncomeInput) => Promise<Income>;
  updateIncome: (input: UpdateIncomeInput) => Promise<Income>;
  voidIncome: (id: string) => Promise<void>;
  getIncomeById: (id: string) => Income | null;
  setFilters: (filters: IncomeFilters) => void;
  filteredIncomes: () => Income[];
}

export const useIncomeStore = create<IncomeState>((set, get) => ({
  incomes: [],
  loading: false,
  error: null,
  filters: {},

  loadIncomes: async () => {
    set({ loading: true, error: null });
    try {
      const database = getSharedDb();
      const { rows } = database.getAllIncomes();
      const incomes: Income[] = rows.map((row) => ({
        id: row.id,
        amount: row.amount,
        currency: row.currency as SupportedCurrency,
        source: row.source ?? '',
        description: row.description,
        date: row.date,
        walletId: row.walletId,
        type: (row.type ?? 'other') as IncomeType,
        status: row.status as 'active' | 'voided',
        clientRequestId: row.clientRequestId ?? undefined,
        createdAt: row.createdAt,
        updatedAt: row.updatedAt,
      }));
      set({ incomes, loading: false });
    } catch (err: any) {
      set({ loading: false, error: err.message ?? 'Failed to load incomes' });
    }
  },

  addIncome: async (input: AddIncomeInput) => {
    set({ loading: true, error: null });
    try {
      const ledgerEngine = getLedger();
      const row = ledgerEngine.createIncome(input);
      const income: Income = {
        id: row.id,
        amount: row.amount,
        currency: row.currency as SupportedCurrency,
        source: row.source ?? '',
        description: row.description,
        date: row.date,
        walletId: row.walletId,
        type: (row.type ?? 'other') as IncomeType,
        status: row.status as 'active' | 'voided',
        clientRequestId: row.clientRequestId ?? undefined,
        createdAt: row.createdAt,
        updatedAt: row.updatedAt,
      };
      set((state) => ({
        incomes: [income, ...state.incomes],
        loading: false,
      }));
      return income;
    } catch (err: any) {
      set({ loading: false, error: err.message ?? 'Failed to add income' });
      throw err;
    }
  },

  updateIncome: async (input: UpdateIncomeInput) => {
    set({ loading: true, error: null });
    try {
      const database = getSharedDb();
      const existing = database.getIncome(input.id);
      if (!existing) throw new Error('NOT_FOUND: income not found');
      if (existing.status === 'voided') throw new Error('ALREADY_VOIDED: cannot update voided income');

      // Validate amount if provided
      if (input.amount !== undefined && input.amount <= 0) {
        throw new Error('VALIDATION_ERROR: amount must be positive');
      }

      const row = database.updateIncome(input.id, {
        amount: input.amount,
        source: input.source,
        description: input.description,
        date: input.date,
      });

      const income: Income = {
        id: row.id,
        amount: row.amount,
        currency: row.currency as SupportedCurrency,
        source: row.source ?? '',
        description: row.description,
        date: row.date,
        walletId: row.walletId,
        type: (row.type ?? 'other') as IncomeType,
        status: row.status as 'active' | 'voided',
        clientRequestId: row.clientRequestId ?? undefined,
        createdAt: row.createdAt,
        updatedAt: row.updatedAt,
      };

      set((state) => ({
        incomes: state.incomes.map((i) => (i.id === input.id ? income : i)),
        loading: false,
      }));
      return income;
    } catch (err: any) {
      set({ loading: false, error: err.message ?? 'Failed to update income' });
      throw err;
    }
  },

  voidIncome: async (id: string) => {
    set({ loading: true, error: null });
    try {
      const ledgerEngine = getLedger();
      ledgerEngine.voidIncome(id);

      set((state) => ({
        incomes: state.incomes.map((i) =>
          i.id === id ? { ...i, status: 'voided' as const, updatedAt: getVietnamNow() } : i
        ),
        loading: false,
      }));
    } catch (err: any) {
      set({ loading: false, error: err.message ?? 'Failed to void income' });
      throw err;
    }
  },

  getIncomeById: (id: string): Income | null => {
    const { incomes } = get();
    return incomes.find((i) => i.id === id) ?? null;
  },

  setFilters: (filters: IncomeFilters) => {
    set({ filters });
  },

  filteredIncomes: (): Income[] => {
    const { incomes, filters } = get();
    let filtered = [...incomes];

    // Filter by type
    if (filters.type && filters.type !== 'all') {
      filtered = filtered.filter((i) => i.type === filters.type);
    }

    // Filter by search text
    if (filters.search) {
      const searchLower = filters.search.toLowerCase();
      filtered = filtered.filter(
        (i) =>
          i.description.toLowerCase().includes(searchLower) ||
          i.source.toLowerCase().includes(searchLower) ||
          INCOME_TYPE_LABELS[i.type].toLowerCase().includes(searchLower)
      );
    }

    // Filter by date range
    if (filters.startDate) {
      const start = new Date(filters.startDate).getTime();
      filtered = filtered.filter((i) => new Date(i.date).getTime() >= start);
    }
    if (filters.endDate) {
      const end = new Date(filters.endDate).getTime();
      filtered = filtered.filter((i) => new Date(i.date).getTime() <= end);
    }

    // Filter by status
    if (filters.status && filters.status !== 'all') {
      filtered = filtered.filter((i) => i.status === filters.status);
    }

    // Sort by date descending (most recent first)
    filtered.sort((a, b) => new Date(b.date).getTime() - new Date(a.date).getTime());

    return filtered;
  },
}));

export { formatCurrency };
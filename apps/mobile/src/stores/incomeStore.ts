// apps/mobile/src/stores/incomeStore.ts
// Income store — CRUD + Soft void + Edit using Zustand (v3: @expense/domain)

import { create } from 'zustand';
import { getSharedDb } from '@expense/domain';

export interface IncomeViewModel {
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
}

export interface AddIncomeInput {
  walletId: string;
  categoryId?: string;
  amountMinor: bigint;
  currency: string;
  source?: string;
  type?: 'salary' | 'freelance' | 'investment' | 'gift' | 'other';
  description?: string;
  occurredAtUtc?: string;
}

export interface UpdateIncomeInput {
  id: string;
  amountMinor?: bigint;
  categoryId?: string;
  source?: string;
  type?: 'salary' | 'freelance' | 'investment' | 'gift' | 'other';
  description?: string;
  occurredAtUtc?: string;
}

export interface IncomeFilters {
  type?: string;
  search?: string;
  startDate?: string;
  endDate?: string;
  status?: 'active' | 'voided' | 'all';
}

interface IncomeState {
  incomes: IncomeViewModel[];
  loading: boolean;
  error: string | null;
  filters: IncomeFilters;

  // Actions
  loadIncomes: () => Promise<void>;
  addIncome: (input: AddIncomeInput) => Promise<IncomeViewModel>;
  updateIncome: (input: UpdateIncomeInput) => Promise<IncomeViewModel>;
  voidIncome: (id: string) => Promise<void>;
  getIncomeById: (id: string) => IncomeViewModel | null;
  setFilters: (filters: IncomeFilters) => void;
  filteredIncomes: () => IncomeViewModel[];
}

function mapToViewModel(i: any): IncomeViewModel {
  return {
    id: i.id,
    walletId: i.walletId,
    categoryId: i.categoryId,
    amountMinor: i.amountMinor,
    currency: i.currency,
    source: i.source,
    type: i.type,
    description: i.description,
    occurredAtUtc: i.occurredAtUtc,
    status: i.status,
    isSample: i.isSample,
  };
}

export const INCOME_TYPE_LABELS: Record<string, string> = {
  salary: 'Lương',
  freelance: 'Thu nhập phụ',
  investment: 'Đầu tư',
  gift: 'Quà tặng',
  other: 'Khác',
};

export const INCOME_TYPE_COLORS: Record<string, string> = {
  salary: '#3B82F6',
  freelance: '#A855F7',
  investment: '#22C55E',
  gift: '#EC4899',
  other: '#64748B',
};

export const INCOME_TYPE_ICONS: Record<string, string> = {
  salary: 'briefcase',
  freelance: 'laptop',
  investment: 'chart-line',
  gift: 'gift',
  other: 'dots-horizontal',
};

export const useIncomeStore = create<IncomeState>((set, get) => ({
  incomes: [],
  loading: false,
  error: null,
  filters: {},

  loadIncomes: async () => {
    set({ loading: true, error: null });
    try {
      const db = getSharedDb();
      const allIncomes = db.getAllIncomes();
      const incomes: IncomeViewModel[] = allIncomes.map(mapToViewModel);
      set({ incomes, loading: false });
    } catch (err: any) {
      set({ loading: false, error: err.message ?? 'Failed to load incomes' });
    }
  },

  addIncome: async (input: AddIncomeInput) => {
    set({ loading: true, error: null });
    try {
      const db = getSharedDb();
      const now = new Date().toISOString();
      const id = crypto.randomUUID();

      const income = db.createIncome({
        id,
        walletId: input.walletId,
        categoryId: input.categoryId,
        amountMinor: input.amountMinor,
        currency: input.currency,
        source: input.source,
        type: input.type ?? 'other',
        description: input.description,
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
        sourceType: 'income',
        sourceId: id,
        entryKind: 'income',
        signedMinor: input.amountMinor,
        currency: input.currency,
        status: 'active',
        occurredAtUtc: input.occurredAtUtc ?? now,
        createdAtUtc: now,
      });

      const incomeVm = mapToViewModel(income);
      set((state) => ({
        incomes: [incomeVm, ...state.incomes],
        loading: false,
      }));
      return incomeVm;
    } catch (err: any) {
      set({ loading: false, error: err.message ?? 'Failed to add income' });
      throw err;
    }
  },

  updateIncome: async (input: UpdateIncomeInput) => {
    set({ loading: true, error: null });
    try {
      const db = getSharedDb();
      const existing = db.getIncome(input.id);
      if (!existing) throw new Error('NOT_FOUND: income not found');
      if (existing.status === 'voided')
        throw new Error('ALREADY_VOIDED: cannot update voided income');

      if (input.amountMinor !== undefined && input.amountMinor <= 0n) {
        throw new Error('VALIDATION_ERROR: amount must be positive');
      }

      // If amount changed, use void-and-recreate pattern to update ledger entry
      if (input.amountMinor !== undefined && input.amountMinor !== existing.amountMinor) {
        // Mark old ledger entry as voided
        const ledgerEntries = db.getLedgerEntries(existing.walletId);
        ledgerEntries
          .filter((e: any) => e.sourceId === input.id && e.sourceType === 'income')
          .forEach((e: any) => {
            e.status = 'voided';
          });

        // Create new ledger entry with updated amount
        const now = new Date().toISOString();
        db.createLedgerEntry({
          id: crypto.randomUUID(),
          walletId: existing.walletId,
          sourceType: 'income',
          sourceId: input.id,
          entryKind: 'income',
          signedMinor: input.amountMinor,
          currency: existing.currency,
          status: 'active',
          occurredAtUtc: existing.occurredAtUtc,
          createdAtUtc: now,
        });
      }

      const income = db.updateIncome(input.id, {
        amountMinor: input.amountMinor,
        categoryId: input.categoryId,
        source: input.source,
        type: input.type,
        description: input.description,
        occurredAtUtc: input.occurredAtUtc,
      } as any);

      const incomeVm = mapToViewModel(income);
      set((state) => ({
        incomes: state.incomes.map((i) => (i.id === input.id ? incomeVm : i)),
        loading: false,
      }));
      return incomeVm;
    } catch (err: any) {
      set({ loading: false, error: err.message ?? 'Failed to update income' });
      throw err;
    }
  },

  voidIncome: async (id: string) => {
    set({ loading: true, error: null });
    try {
      const db = getSharedDb();
      const existing = db.getIncome(id);
      if (!existing) throw new Error('NOT_FOUND: income not found');

      db.updateIncome(id, { status: 'voided' } as any);

      // Mark ledger entry as voided
      const ledgerEntries = db.getLedgerEntries(existing.walletId);
      ledgerEntries
        .filter((e: any) => e.sourceId === id && e.sourceType === 'income')
        .forEach((e: any) => {
          e.status = 'voided';
        });

      set((state) => ({
        incomes: state.incomes.map((i) => (i.id === id ? { ...i, status: 'voided' as const } : i)),
        loading: false,
      }));
    } catch (err: any) {
      set({ loading: false, error: err.message ?? 'Failed to void income' });
      throw err;
    }
  },

  getIncomeById: (id: string): IncomeViewModel | null => {
    const { incomes } = get();
    return incomes.find((i) => i.id === id) ?? null;
  },

  setFilters: (filters: IncomeFilters) => {
    set({ filters });
  },

  filteredIncomes: (): IncomeViewModel[] => {
    const { incomes, filters } = get();
    let filtered = [...incomes];

    if (filters.type && filters.type !== 'all') {
      filtered = filtered.filter((i) => i.type === filters.type);
    }

    if (filters.search) {
      const searchLower = filters.search.toLowerCase();
      filtered = filtered.filter(
        (i) =>
          (i.description && i.description.toLowerCase().includes(searchLower)) ||
          (i.source && i.source.toLowerCase().includes(searchLower)),
      );
    }

    if (filters.startDate) {
      filtered = filtered.filter((i) => i.occurredAtUtc >= filters.startDate!);
    }
    if (filters.endDate) {
      filtered = filtered.filter((i) => i.occurredAtUtc <= filters.endDate!);
    }

    if (filters.status && filters.status !== 'all') {
      filtered = filtered.filter((i) => i.status === filters.status);
    }

    filtered.sort((a, b) => b.occurredAtUtc.localeCompare(a.occurredAtUtc));
    return filtered;
  },
}));

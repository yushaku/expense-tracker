// apps/mobile/src/stores/dashboardStore.ts
// Dashboard store — Cash flow, Savings rate, Category breakdown, Wallet balances (v3: @expense/domain)

import { create } from 'zustand';
import { getSharedDb, formatMoney } from '@expense/domain';

export interface CategoryBreakdownItem {
  categoryId: string;
  label: string;
  amountMinor: bigint;
  percentage: number;
  color: string;
}

export interface WalletBalanceItem {
  id: string;
  name: string;
  type: string;
  balanceMinor: bigint;
  currency: string;
  creditLimitMinor: bigint;
}

interface DashboardState {
  cashFlowMinor: bigint;
  totalIncomeMinor: bigint;
  totalExpenseMinor: bigint;
  savingsRate: number;
  categoryBreakdown: CategoryBreakdownItem[];
  walletBalances: WalletBalanceItem[];
  loading: boolean;
  error: string | null;

  // Actions
  loadDashboardData: () => Promise<void>;
  refreshDashboard: () => Promise<void>;
}

const CATEGORY_COLORS: Record<string, string> = {
  cat_food: '#F97316',
  cat_transport: '#3B82F6',
  cat_shopping: '#EC4899',
  cat_entertainment: '#A855F7',
  cat_healthcare: '#EF4444',
  cat_education: '#6366F1',
  cat_bills: '#78716C',
  cat_other: '#64748B',
};

const CATEGORY_LABELS: Record<string, string> = {
  cat_food: 'Ăn uống',
  cat_transport: 'Di chuyển',
  cat_shopping: 'Mua sắm',
  cat_entertainment: 'Giải trí',
  cat_healthcare: 'Y tế',
  cat_education: 'Giáo dục',
  cat_bills: 'Hóa đơn',
  cat_other: 'Khác',
};

export const useDashboardStore = create<DashboardState>((set, get) => ({
  cashFlowMinor: 0n,
  totalIncomeMinor: 0n,
  totalExpenseMinor: 0n,
  savingsRate: 0,
  categoryBreakdown: [],
  walletBalances: [],
  loading: false,
  error: null,

  loadDashboardData: async () => {
    set({ loading: true, error: null });
    try {
      const db = getSharedDb();
      const now = new Date();
      const year = now.getUTCFullYear();
      const month = now.getUTCMonth();
      const monthStart = new Date(Date.UTC(year, month, 1)).toISOString();
      const monthEnd = new Date(Date.UTC(year, month + 1, 0, 23, 59, 59)).toISOString();

      const allExpenses = db.getAllExpenses();
      const allIncomes = db.getAllIncomes();

      const activeExpenses = allExpenses.filter(
        (e: any) =>
          e.status === 'active' && e.occurredAtUtc >= monthStart && e.occurredAtUtc <= monthEnd,
      );
      const activeIncomes = allIncomes.filter(
        (i: any) =>
          i.status === 'active' && i.occurredAtUtc >= monthStart && i.occurredAtUtc <= monthEnd,
      );

      const totalExpense = activeExpenses.reduce((sum: bigint, e: any) => sum + e.amountMinor, 0n);
      const totalIncome = activeIncomes.reduce((sum: bigint, i: any) => sum + i.amountMinor, 0n);
      const cashFlowMinor = totalIncome - totalExpense;

      // Use BigInt arithmetic for savings rate (avoid precision loss with Number())
      const savingsRate =
        totalIncome > 0n ? Number((cashFlowMinor * 1000n) / totalIncome) / 10 : 0;

      const categoryTotals: Record<string, bigint> = {};
      activeExpenses.forEach((e: any) => {
        categoryTotals[e.categoryId] = (categoryTotals[e.categoryId] ?? 0n) + e.amountMinor;
      });

      const categoryBreakdown: CategoryBreakdownItem[] = Object.entries(categoryTotals)
        .map(([categoryId, amountMinor]) => ({
          categoryId,
          label: CATEGORY_LABELS[categoryId] ?? categoryId,
          amountMinor,
          percentage: totalExpense > 0n ? Number((amountMinor * 1000n) / totalExpense) / 10 : 0,
          color: CATEGORY_COLORS[categoryId] ?? '#64748B',
        }))
        .filter((item) => item.percentage > 0)
        .sort((a, b) => Number(b.amountMinor - a.amountMinor));

      const walletRows = db.getAllWallets();
      const walletBalances: WalletBalanceItem[] = walletRows.map((w: any) => ({
        id: w.id,
        name: w.name,
        type: w.type,
        balanceMinor: db.getBalance(w.id),
        currency: w.currency,
        creditLimitMinor: w.creditLimitMinor,
      }));

      set({
        cashFlowMinor,
        totalIncomeMinor: totalIncome,
        totalExpenseMinor: totalExpense,
        savingsRate,
        categoryBreakdown,
        walletBalances,
        loading: false,
      });
    } catch (err: any) {
      set({ loading: false, error: err.message ?? 'Failed to load dashboard data' });
    }
  },

  refreshDashboard: async () => {
    await get().loadDashboardData();
  },
}));

export { formatMoney, CATEGORY_LABELS };

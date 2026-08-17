// apps/mobile/src/stores/dashboardStore.ts
// Dashboard store — Cash flow, Savings rate, Category breakdown, Wallet balances

import { create } from 'zustand';
import {
  ExpenseCategory,
  SupportedCurrency,
  WalletWithBalance,
  LedgerEngine,
  formatCurrency,
  CATEGORY_LABELS,
  getSharedDb,
  getVietnamNow,
} from '@expense/shared';

// Singleton ledger instance (shares DB with other stores)
let ledger: LedgerEngine | null = null;

function getLedger(): LedgerEngine {
  if (!ledger) {
    ledger = new LedgerEngine(getSharedDb());
  }
  return ledger;
}

export interface CategoryBreakdownItem {
  category: ExpenseCategory;
  label: string;
  amount: number;
  percentage: number;
  color: string;
}

export interface WalletBalanceItem {
  id: string;
  name: string;
  type: string;
  balance: number;
  currency: SupportedCurrency;
  creditLimit: number;
}

interface DashboardState {
  cashFlow: number;
  savingsRate: number;
  categoryBreakdown: CategoryBreakdownItem[];
  walletBalances: WalletBalanceItem[];
  loading: boolean;
  error: string | null;

  // Actions
  loadDashboardData: () => Promise<void>;
  refreshDashboard: () => Promise<void>;
}

// Category colors from design system
const CATEGORY_COLORS: Record<ExpenseCategory, string> = {
  food: '#F97316',
  transport: '#3B82F6',
  shopping: '#EC4899',
  entertainment: '#A855F7',
  healthcare: '#EF4444',
  education: '#6366F1',
  bills: '#78716C',
  savings: '#0369A1',
  other: '#64748B',
};

// Wallet type icons
const WALLET_TYPE_ICONS: Record<string, string> = {
  cash: 'cash',
  bank: 'bank',
  ewallet: 'cellphone',
  credit_card: 'credit-card',
};

export const useDashboardStore = create<DashboardState>((set, get) => ({
  cashFlow: 0,
  savingsRate: 0,
  categoryBreakdown: [],
  walletBalances: [],
  loading: false,
  error: null,

  loadDashboardData: async () => {
    set({ loading: true, error: null });
    try {
      const database = getSharedDb();
      const ledgerEngine = getLedger();
      const now = new Date();
      const year = now.getFullYear();
      const month = now.getMonth();
      const monthStart = new Date(year, month, 1).toISOString();
      const monthEnd = new Date(year, month + 1, 0, 23, 59, 59).toISOString();

      // Get all active expenses and incomes for current month
      const { rows: allExpenses } = database.getAllExpenses();
      const { rows: allIncomes } = database.getAllIncomes();

      const activeExpenses = allExpenses.filter(
        (e) => e.status === 'active' && e.date >= monthStart && e.date <= monthEnd
      );
      const activeIncomes = allIncomes.filter(
        (i) => i.status === 'active' && i.date >= monthStart && i.date <= monthEnd
      );

      // Calculate cash flow
      const totalExpense = activeExpenses.reduce((sum, e) => sum + e.amount, 0);
      const totalIncome = activeIncomes.reduce((sum, i) => sum + i.amount, 0);
      const cashFlow = totalIncome - totalExpense;

      // Calculate savings rate
      const savingsRate = totalIncome > 0 ? (cashFlow / totalIncome) * 100 : 0;

      // Calculate category breakdown
      const categoryTotals: Record<string, number> = {};
      activeExpenses.forEach((e) => {
        categoryTotals[e.category] = (categoryTotals[e.category] || 0) + e.amount;
      });

      const categoryBreakdown: CategoryBreakdownItem[] = Object.entries(categoryTotals)
        .map(([category, amount]) => ({
          category: category as ExpenseCategory,
          label: CATEGORY_LABELS[category as ExpenseCategory],
          amount,
          percentage: totalExpense > 0 ? (amount / totalExpense) * 100 : 0,
          color: CATEGORY_COLORS[category as ExpenseCategory],
        }))
        .filter((item) => item.percentage > 0)
        .sort((a, b) => b.amount - a.amount);

      // Calculate wallet balances
      const walletRows = database.getAllWallets();
      const walletBalances: WalletBalanceItem[] = walletRows.map((w) => ({
        id: w.id,
        name: w.name,
        type: w.type,
        balance: ledgerEngine.getWalletBalance(w.id),
        currency: w.currency as SupportedCurrency,
        creditLimit: w.creditLimit,
      }));

      set({
        cashFlow,
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

export { formatCurrency, CATEGORY_LABELS, WALLET_TYPE_ICONS };
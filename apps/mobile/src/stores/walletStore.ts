// apps/mobile/src/stores/walletStore.ts
// Wallet store — CRUD + Transfer using Zustand

import { create } from 'zustand';
import {
  WalletType,
  SupportedCurrency,
  WalletWithBalance,
  CreateWalletInput,
  UpdateWalletInput,
  TransferInput,
  LedgerEngine,
  Database,
  generateId,
  formatCurrency,
} from '@expense/shared';

// Database row types matching @expense/shared
interface WalletRow {
  id: string;
  name: string;
  type: WalletType;
  currency: SupportedCurrency;
  creditLimit: number;
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

// Simple in-memory database for mobile (Phase 1)
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

interface WalletState {
  wallets: WalletWithBalance[];
  selectedWalletId: string | null;
  loading: boolean;
  error: string | null;

  // Actions
  loadWallets: () => Promise<void>;
  createWallet: (input: CreateWalletInput) => Promise<WalletWithBalance>;
  updateWallet: (input: UpdateWalletInput) => Promise<WalletWithBalance>;
  deleteWallet: (id: string) => Promise<void>;
  transfer: (input: TransferInput) => Promise<void>;
  getWalletById: (id: string) => WalletWithBalance | null;
  setSelectedWallet: (id: string | null) => void;
}

export const useWalletStore = create<WalletState>((set, get) => ({
  wallets: [],
  selectedWalletId: null,
  loading: false,
  error: null,

  loadWallets: async () => {
    set({ loading: true, error: null });
    try {
      const database = getDb();
      const ledgerEngine = getLedger();
      const walletRows = database.getAllWallets();
      const walletsWithBalance: WalletWithBalance[] = walletRows.map((w) => ({
        ...w,
        balance: ledgerEngine.getWalletBalance(w.id),
      }));
      set({ wallets: walletsWithBalance, loading: false });
    } catch (err: any) {
      set({ loading: false, error: err.message ?? 'Failed to load wallets' });
    }
  },

  createWallet: async (input: CreateWalletInput) => {
    set({ loading: true, error: null });
    try {
      const database = getDb();
      const ledgerEngine = getLedger();
      const id = generateId();
      const now = new Date().toISOString();

      const wallet = database.createWallet({
        id,
        name: input.name,
        type: input.type,
        currency: input.currency ?? 'VND',
        creditLimit: input.creditLimit ?? 0,
      });

      // Create opening balance ledger entry if > 0
      if (input.openingBalance > 0) {
        database.createLedgerEntry({
          id: generateId(),
          walletId: id,
          type: 'opening_balance',
          amount: input.openingBalance,
          refId: id,
          refType: 'wallet',
          date: now,
          status: 'active',
        });
      }

      const walletWithBalance: WalletWithBalance = {
        ...wallet,
        balance: ledgerEngine.getWalletBalance(id),
      };

      set((state) => ({
        wallets: [...state.wallets, walletWithBalance],
        loading: false,
      }));

      return walletWithBalance;
    } catch (err: any) {
      set({ loading: false, error: err.message ?? 'Failed to create wallet' });
      throw err;
    }
  },

  updateWallet: async (input: UpdateWalletInput) => {
    set({ loading: true, error: null });
    try {
      const database = getDb();
      const ledgerEngine = getLedger();

      const wallet = database.updateWallet(input.id, {
        name: input.name,
        creditLimit: input.creditLimit,
      });

      const walletWithBalance: WalletWithBalance = {
        ...wallet,
        balance: ledgerEngine.getWalletBalance(input.id),
      };

      set((state) => ({
        wallets: state.wallets.map((w) => (w.id === input.id ? walletWithBalance : w)),
        loading: false,
      }));

      return walletWithBalance;
    } catch (err: any) {
      set({ loading: false, error: err.message ?? 'Failed to update wallet' });
      throw err;
    }
  },

  deleteWallet: async (id: string) => {
    set({ loading: true, error: null });
    try {
      const database = getDb();
      database.deleteWallet(id);
      set((state) => ({
        wallets: state.wallets.filter((w) => w.id !== id),
        selectedWalletId: state.selectedWalletId === id ? null : state.selectedWalletId,
        loading: false,
      }));
    } catch (err: any) {
      set({ loading: false, error: err.message ?? 'Failed to delete wallet' });
      throw err;
    }
  },

  transfer: async (input: TransferInput) => {
    set({ loading: true, error: null });
    try {
      const ledgerEngine = getLedger();
      ledgerEngine.createTransfer(input);

      // Refresh wallets after transfer
      await get().loadWallets();
      set({ loading: false });
    } catch (err: any) {
      set({ loading: false, error: err.message ?? 'Failed to transfer' });
      throw err;
    }
  },

  getWalletById: (id: string): WalletWithBalance | null => {
    const { wallets } = get();
    return wallets.find((w) => w.id === id) ?? null;
  },

  setSelectedWallet: (id: string | null) => {
    set({ selectedWalletId: id });
  },
}));

export { formatCurrency };
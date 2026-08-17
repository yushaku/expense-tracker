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
  generateId,
  formatCurrency,
  getSharedDb,
  WalletRow,
  getVietnamNow,
} from '@expense/shared';

// Singleton ledger instance (shares DB with expenseStore)
let ledger: LedgerEngine | null = null;

function getLedger(): LedgerEngine {
  if (!ledger) {
    ledger = new LedgerEngine(getSharedDb());
  }
  return ledger;
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
      const database = getSharedDb();
      const ledgerEngine = getLedger();
      const walletRows = database.getAllWallets();
      const walletsWithBalance: WalletWithBalance[] = walletRows.map((w: WalletRow) => ({
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
      const database = getSharedDb();
      const ledgerEngine = getLedger();
      const id = generateId();
      const now = getVietnamNow();

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
      const database = getSharedDb();
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
      const database = getSharedDb();
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

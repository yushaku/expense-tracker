// apps/mobile/src/stores/walletStore.ts
// Wallet store — CRUD + Transfer using Zustand (v3: @expense/domain)

import { create } from 'zustand';
import {
  WalletService,
  CreateWalletInput,
  CreateTransferInput,
  getSharedDb,
} from '@expense/domain';

// Singleton wallet service (shares DB with other stores)
let service: WalletService | null = null;

function getService(): WalletService {
  if (!service) {
    service = new WalletService(getSharedDb());
  }
  return service;
}

export interface WalletWithBalance {
  id: string;
  name: string;
  type: 'cash' | 'bank' | 'ewallet' | 'credit_card';
  currency: string;
  creditLimitMinor: bigint;
  balanceMinor: bigint;
}

export interface TransferInput {
  fromWalletId: string;
  toWalletId: string;
  amount: bigint;
  note?: string;
}

interface WalletState {
  wallets: WalletWithBalance[];
  selectedWalletId: string | null;
  loading: boolean;
  error: string | null;

  // Actions
  loadWallets: () => Promise<void>;
  createWallet: (input: CreateWalletInput) => Promise<WalletWithBalance>;
  updateWallet: (input: {
    id: string;
    name?: string;
    creditLimitMinor?: bigint;
  }) => Promise<WalletWithBalance>;
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
      const svc = getService();
      const db = getSharedDb();
      const allWallets = db.getAllWallets();
      const walletsWithBalance: WalletWithBalance[] = allWallets.map((w: any) => ({
        ...w,
        balanceMinor: svc.getBalance(w.id),
      }));
      set({ wallets: walletsWithBalance, loading: false });
    } catch (err: any) {
      set({ loading: false, error: err.message ?? 'Failed to load wallets' });
    }
  },

  createWallet: async (input: CreateWalletInput) => {
    set({ loading: true, error: null });
    try {
      const svc = getService();
      const wallet = svc.createWallet(input);
      const balanceMinor = svc.getBalance(wallet.id);

      const walletWithBalance: WalletWithBalance = {
        id: wallet.id,
        name: wallet.name,
        type: wallet.type,
        currency: wallet.currency,
        creditLimitMinor: wallet.creditLimitMinor,
        balanceMinor,
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

  updateWallet: async (input: { id: string; name?: string; creditLimitMinor?: bigint }) => {
    set({ loading: true, error: null });
    try {
      const db = getSharedDb();
      const svc = getService();

      const wallet = db.updateWallet(input.id, {
        name: input.name,
        creditLimitMinor: input.creditLimitMinor,
      } as any);

      const walletWithBalance: WalletWithBalance = {
        id: wallet.id,
        name: wallet.name,
        type: wallet.type,
        currency: wallet.currency,
        creditLimitMinor: wallet.creditLimitMinor,
        balanceMinor: svc.getBalance(wallet.id),
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
      const db = getSharedDb();
      db.deleteWallet(id);
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
      const svc = getService();
      const db = getSharedDb();
      const fromWallet = db.getWallet(input.fromWalletId);
      const currency = fromWallet?.currency ?? 'VND';
      svc.createTransfer({
        fromWalletId: input.fromWalletId,
        toWalletId: input.toWalletId,
        amount: { minorUnits: input.amount, currency },
      });

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

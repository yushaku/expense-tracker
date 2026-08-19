// packages/domain/src/wallet.ts
// Wallet domain service — wallet CRUD, credit card accounting, transfer

import type { Money } from './money.js';
import { InMemoryDatabase } from './database.js';
import type { Wallet } from './database.js';

export interface CreateWalletInput {
  name: string;
  type: 'cash' | 'bank' | 'ewallet' | 'credit_card';
  currency: string;
  openingBalance?: bigint;
  creditLimitMinor?: bigint;
}

export interface PostExpenseInput {
  walletId: string;
  amount: Money;
  categoryId: string;
}

export interface CreateTransferInput {
  fromWalletId: string;
  toWalletId: string;
  amount: Money;
}

function generateId(): string {
  return crypto.randomUUID();
}

export interface CreditCardInfo {
  debt: bigint;
  payments: bigint;
  available: bigint;
  creditLimit: bigint;
}

export class WalletService {
  constructor(private db: InMemoryDatabase) {}

  createWallet(input: CreateWalletInput): Wallet {
    if (input.type === 'credit_card' && (!input.creditLimitMinor || input.creditLimitMinor <= 0n)) {
      throw new Error('INVALID_CREDIT_LIMIT: credit card must have credit limit > 0');
    }

    if (input.type !== 'credit_card' && input.creditLimitMinor && input.creditLimitMinor > 0n) {
      throw new Error('INVALID_CREDIT_LIMIT: only credit card can have credit limit');
    }

    const now = new Date().toISOString();
    const wallet: Wallet = {
      id: generateId(),
      name: input.name,
      type: input.type,
      currency: input.currency,
      creditLimitMinor: input.creditLimitMinor ?? 0n,
      status: 'active',
      createdAtUtc: now,
      updatedAtUtc: now,
    };

    this.db.createWallet(wallet);

    // Create opening balance ledger entry if > 0
    if (input.openingBalance && input.openingBalance > 0n) {
      this.db.createLedgerEntry({
        id: generateId(),
        walletId: wallet.id,
        sourceType: 'opening_balance',
        sourceId: wallet.id,
        entryKind: 'opening_balance',
        signedMinor: input.openingBalance,
        currency: input.currency,
        status: 'active',
        occurredAtUtc: now,
        createdAtUtc: now,
      });
    }

    return wallet;
  }

  getWallet(id: string): Wallet {
    const wallet = this.db.getWallet(id);
    if (!wallet) throw new Error('WALLET_NOT_FOUND');
    return wallet;
  }

  getBalance(walletId: string): bigint {
    return this.db.getBalance(walletId);
  }

  postExpense(input: PostExpenseInput): void {
    const wallet = this.getWallet(input.walletId);
    if (wallet.status === 'voided') throw new Error('WALLET_VOIDED');

    const now = new Date().toISOString();
    const signedMinor = input.amount.minorUnits;

    this.db.createLedgerEntry({
      id: generateId(),
      walletId: input.walletId,
      sourceType: 'expense',
      sourceId: generateId(),
      entryKind: 'expense',
      signedMinor,
      currency: input.amount.currency,
      status: 'active',
      occurredAtUtc: now,
      createdAtUtc: now,
    });
  }

  createTransfer(input: CreateTransferInput): void {
    if (input.fromWalletId === input.toWalletId) {
      throw new Error('TRANSFER_SAME_WALLET');
    }

    const fromWallet = this.getWallet(input.fromWalletId);
    const toWallet = this.getWallet(input.toWalletId);

    if (fromWallet.status === 'voided' || toWallet.status === 'voided') {
      throw new Error('WALLET_VOIDED');
    }

    if (
      fromWallet.currency !== input.amount.currency ||
      toWallet.currency !== input.amount.currency
    ) {
      throw new Error('CURRENCY_MISMATCH');
    }

    const now = new Date().toISOString();
    const transferId = generateId();

    // Outgoing leg (negative — reduces from-wallet balance)
    this.db.createLedgerEntry({
      id: generateId(),
      walletId: input.fromWalletId,
      sourceType: 'transfer',
      sourceId: transferId,
      entryKind: 'transfer_out',
      signedMinor: -input.amount.minorUnits,
      currency: input.amount.currency,
      status: 'active',
      occurredAtUtc: now,
      createdAtUtc: now,
    });

    // Incoming leg
    this.db.createLedgerEntry({
      id: generateId(),
      walletId: input.toWalletId,
      sourceType: 'transfer',
      sourceId: transferId,
      entryKind: 'transfer_in',
      signedMinor: input.amount.minorUnits,
      currency: input.amount.currency,
      status: 'active',
      occurredAtUtc: now,
      createdAtUtc: now,
    });
  }

  getCreditCardInfo(walletId: string): CreditCardInfo {
    const wallet = this.getWallet(walletId);
    if (wallet.type !== 'credit_card') {
      throw new Error('NOT_CREDIT_CARD');
    }

    const entries = this.db.getLedgerEntries(walletId);
    let debt = 0n;
    let payments = 0n;

    for (const entry of entries) {
      if (entry.status !== 'active') continue;
      if (entry.entryKind === 'expense') {
        debt += entry.signedMinor;
      } else if (entry.entryKind === 'transfer_in') {
        payments += entry.signedMinor;
      }
    }

    const netDebt = debt - payments;
    const available = wallet.creditLimitMinor - netDebt;

    return {
      debt: netDebt,
      payments,
      available,
      creditLimit: wallet.creditLimitMinor,
    };
  }
}

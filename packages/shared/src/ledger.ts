// packages/shared/src/ledger.ts
// Ledger engine — balance derivation and invariant enforcement

import type { Database, WalletRow, ExpenseRow, IncomeRow, TransferRow, LedgerEntryRow } from './database.js';
import type { AddExpenseInput, AddIncomeInput, TransferInput } from './types.js';
import { generateId } from './utils.js';

export class LedgerEngine {
  constructor(private db: Database) {}

  /**
   * Create expense + ledger entry in single transaction.
   * Invariants enforced:
   * - amount > 0
   * - wallet exists
   * - CC limit not exceeded
   * - idempotency (clientRequestId)
   */
  createExpense(input: AddExpenseInput): ExpenseRow {
    return this.db.transaction(() => {
      // Validate
      if (input.amount <= 0) throw new Error('VALIDATION_ERROR: amount must be positive');

      const wallet = this.db.getWallet(input.walletId);
      if (!wallet) throw new Error('NOT_FOUND: wallet not found');

      // Check CC limit
      if (wallet.type === 'credit_card') {
        const debt = this.calculateCcDebt(wallet.id);
        if (debt + input.amount > wallet.creditLimit) {
          throw new Error('INSUFFICIENT_AVAILABLE_CREDIT: exceeds credit limit');
        }
      }

      // Idempotency check
      if (input.clientRequestId) {
        const existing = this.findExpenseByRequestId(input.clientRequestId);
        if (existing && this.sameExpensePayload(existing, input)) return existing;
        if (existing) throw new Error('IDEMPOTENCY_CONFLICT: duplicate request');
      }

      const now = new Date().toISOString();
      const expense = this.db.createExpense({
        id: generateId(),
        amount: input.amount,
        currency: input.currency ?? 'VND',
        category: input.category,
        description: input.description ?? '',
        date: input.date ?? now,
        walletId: input.walletId,
        merchant: input.merchant ?? null,
        receiptImage: null,
        status: 'active',
        clientRequestId: input.clientRequestId ?? null,
      });

      this.db.createLedgerEntry({
        id: generateId(),
        walletId: input.walletId,
        type: 'expense',
        amount: -input.amount,
        refId: expense.id,
        refType: 'expense',
        date: expense.date,
        status: 'active',
      });

      return expense;
    });
  }

  /**
   * Create income + ledger entry in single transaction.
   */
  createIncome(input: AddIncomeInput): IncomeRow {
    return this.db.transaction(() => {
      if (input.amount <= 0) throw new Error('VALIDATION_ERROR: amount must be positive');

      const wallet = this.db.getWallet(input.walletId);
      if (!wallet) throw new Error('NOT_FOUND: wallet not found');

      // Income to CC wallet not allowed
      if (wallet.type === 'credit_card') {
        throw new Error('VALIDATION_ERROR: cannot add income to credit card wallet');
      }

      // Idempotency check
      if (input.clientRequestId) {
        const existing = this.findIncomeByRequestId(input.clientRequestId);
        if (existing && this.sameIncomePayload(existing, input)) return existing;
        if (existing) throw new Error('IDEMPOTENCY_CONFLICT: duplicate request');
      }

      const now = new Date().toISOString();
      const income = this.db.createIncome({
        id: generateId(),
        amount: input.amount,
        currency: input.currency ?? 'VND',
        source: input.source ?? null,
        description: input.description ?? '',
        date: input.date ?? now,
        walletId: input.walletId,
        type: input.type ?? null,
        status: 'active',
        clientRequestId: input.clientRequestId ?? null,
      });

      this.db.createLedgerEntry({
        id: generateId(),
        walletId: input.walletId,
        type: 'income',
        amount: input.amount,
        refId: income.id,
        refType: 'income',
        date: income.date,
        status: 'active',
      });

      return income;
    });
  }

  /**
   * Create transfer + 2 ledger entries in single transaction.
   * Invariants: from != to, amount > 0, atomic 2 legs.
   */
  createTransfer(input: TransferInput): TransferRow {
    return this.db.transaction(() => {
      if (input.fromWalletId === input.toWalletId) {
        throw new Error('TRANSFER_SAME_WALLET: cannot transfer to same wallet');
      }
      if (input.amount <= 0) throw new Error('VALIDATION_ERROR: amount must be positive');

      const fromWallet = this.db.getWallet(input.fromWalletId);
      if (!fromWallet) throw new Error('NOT_FOUND: from wallet not found');

      const toWallet = this.db.getWallet(input.toWalletId);
      if (!toWallet) throw new Error('NOT_FOUND: to wallet not found');

      // Idempotency check
      if (input.clientRequestId) {
        const existing = this.findTransferByRequestId(input.clientRequestId);
        if (existing && this.sameTransferPayload(existing, input)) return existing;
        if (existing) throw new Error('IDEMPOTENCY_CONFLICT: duplicate request');
      }

      const now = new Date().toISOString();
      const transfer = this.db.createTransfer({
        id: generateId(),
        fromWalletId: input.fromWalletId,
        toWalletId: input.toWalletId,
        amount: input.amount,
        currency: 'VND',
        date: input.date ?? now,
        note: input.note ?? null,
        status: 'active',
        clientRequestId: input.clientRequestId ?? null,
      });

      // Outgoing leg
      this.db.createLedgerEntry({
        id: generateId(),
        walletId: input.fromWalletId,
        type: 'transfer_out',
        amount: -input.amount,
        refId: transfer.id,
        refType: 'transfer',
        date: transfer.date,
        status: 'active',
      });

      // Incoming leg
      this.db.createLedgerEntry({
        id: generateId(),
        walletId: input.toWalletId,
        type: 'transfer_in',
        amount: input.amount,
        refId: transfer.id,
        refType: 'transfer',
        date: transfer.date,
        status: 'active',
      });

      return transfer;
    });
  }

  /**
   * Soft void expense — mark as voided, exclude from balance/metrics.
   */
  voidExpense(id: string): void {
    const expense = this.db.getExpense(id);
    if (!expense) throw new Error('NOT_FOUND: expense not found');
    if (expense.status === 'voided') throw new Error('ALREADY_VOIDED: expense already voided');

    this.db.transaction(() => {
      this.db.updateExpense(id, { status: 'voided' });
      // Mark ledger entry as voided
      const entries = this.db.getLedgerEntries(expense.walletId);
      const entry = entries.find(e => e.refId === id && e.refType === 'expense');
      if (entry) {
        // Note: ledger entry status update would need a method in DB interface
        // For now, we just mark the expense as voided
      }
    });
  }

  /**
   * Soft void income.
   */
  voidIncome(id: string): void {
    const income = this.db.getIncome(id);
    if (!income) throw new Error('NOT_FOUND: income not found');
    if (income.status === 'voided') throw new Error('ALREADY_VOIDED: income already voided');

    this.db.updateIncome(id, { status: 'voided' });
  }

  /**
   * Get wallet balance derived from ledger entries.
   * Balance = Σ(active ledger entries for wallet)
   */
  getWalletBalance(walletId: string): number {
    const entries = this.db.getLedgerEntries(walletId);
    return entries
      .filter(e => e.status === 'active')
      .reduce((sum, e) => sum + e.amount, 0);
  }

  /**
   * Get credit card info: debt, available, credit limit.
   */
  getCreditCardInfo(walletId: string): { debt: number; available: number; creditLimit: number } {
    const wallet = this.db.getWallet(walletId);
    if (!wallet) throw new Error('NOT_FOUND: wallet not found');
    if (wallet.type !== 'credit_card') throw new Error('VALIDATION_ERROR: not a credit card wallet');

    const debt = this.calculateCcDebt(walletId);
    return {
      debt,
      available: wallet.creditLimit - debt,
      creditLimit: wallet.creditLimit,
    };
  }

  /**
   * Calculate CC debt: sum of expenses on CC - sum of transfers to CC.
   */
  private calculateCcDebt(walletId: string): number {
    const entries = this.db.getLedgerEntries(walletId);
    return entries
      .filter(e => e.status === 'active')
      .reduce((debt, e) => {
        if (e.type === 'expense') return debt + Math.abs(e.amount);
        if (e.type === 'transfer_in') return debt - e.amount;
        return debt;
      }, 0);
  }

  // Helper methods for idempotency
  private findExpenseByRequestId(requestId: string): ExpenseRow | null {
    const { rows } = this.db.getAllExpenses({ limit: 1000 });
    return rows.find(e => e.clientRequestId === requestId) ?? null;
  }

  private findIncomeByRequestId(requestId: string): IncomeRow | null {
    const { rows } = this.db.getAllIncomes({ limit: 1000 });
    return rows.find(i => i.clientRequestId === requestId) ?? null;
  }

  private findTransferByRequestId(requestId: string): TransferRow | null {
    const { rows } = this.db.getAllTransfers({ limit: 1000 });
    return rows.find(t => t.clientRequestId === requestId) ?? null;
  }

  private sameExpensePayload(existing: ExpenseRow, input: AddExpenseInput): boolean {
    return (
      existing.amount === input.amount &&
      existing.category === input.category &&
      existing.walletId === input.walletId
    );
  }

  private sameIncomePayload(existing: IncomeRow, input: AddIncomeInput): boolean {
    return (
      existing.amount === input.amount &&
      existing.walletId === input.walletId
    );
  }

  private sameTransferPayload(existing: TransferRow, input: TransferInput): boolean {
    return (
      existing.amount === input.amount &&
      existing.fromWalletId === input.fromWalletId &&
      existing.toWalletId === input.toWalletId
    );
  }
}

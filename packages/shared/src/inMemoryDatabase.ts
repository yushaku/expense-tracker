// packages/shared/src/inMemoryDatabase.ts
// In-memory database implementation for mobile (Phase 1) — shared across all stores

import type {
  Database,
  WalletRow,
  ExpenseRow,
  IncomeRow,
  TransferRow,
  LedgerEntryRow,
  BudgetRow,
  InvestmentRow,
  QueryOptions,
  QueryResult,
} from './database.js';
import { getVietnamNow } from './utils.js';

export class InMemoryDatabase implements Database {
  private wallets: Map<string, WalletRow> = new Map();
  private expenses: Map<string, ExpenseRow> = new Map();
  private incomes: Map<string, IncomeRow> = new Map();
  private transfers: Map<string, TransferRow> = new Map();
  private ledgerEntries: Map<string, LedgerEntryRow> = new Map();
  private budgets: Map<string, BudgetRow> = new Map();
  private investments: Map<string, InvestmentRow> = new Map();

  // Wallets
  createWallet(data: Omit<WalletRow, 'createdAt' | 'updatedAt'>): WalletRow {
    const now = getVietnamNow();
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
    const updated = { ...wallet, ...updates, updatedAt: getVietnamNow() };
    this.wallets.set(id, updated);
    return updated;
  }

  deleteWallet(id: string): boolean {
    return this.wallets.delete(id);
  }

  // Expenses
  createExpense(data: Omit<ExpenseRow, 'createdAt' | 'updatedAt'>): ExpenseRow {
    const now = getVietnamNow();
    const expense = { ...data, createdAt: now, updatedAt: now };
    this.expenses.set(data.id, expense);
    return expense;
  }

  getExpense(id: string): ExpenseRow | null {
    return this.expenses.get(id) ?? null;
  }

  getAllExpenses(options?: QueryOptions): QueryResult<ExpenseRow> {
    const rows = Array.from(this.expenses.values());
    return { rows, total: rows.length };
  }

  updateExpense(id: string, updates: Partial<ExpenseRow>): ExpenseRow {
    const expense = this.expenses.get(id);
    if (!expense) throw new Error('NOT_FOUND: expense not found');
    const updated = { ...expense, ...updates, updatedAt: getVietnamNow() };
    this.expenses.set(id, updated);
    return updated;
  }

  deleteExpense(id: string): boolean {
    return this.expenses.delete(id);
  }

  // Incomes
  createIncome(data: Omit<IncomeRow, 'createdAt' | 'updatedAt'>): IncomeRow {
    const now = getVietnamNow();
    const income = { ...data, createdAt: now, updatedAt: now };
    this.incomes.set(data.id, income);
    return income;
  }

  getIncome(id: string): IncomeRow | null {
    return this.incomes.get(id) ?? null;
  }

  getAllIncomes(options?: QueryOptions): QueryResult<IncomeRow> {
    const rows = Array.from(this.incomes.values());
    return { rows, total: rows.length };
  }

  updateIncome(id: string, updates: Partial<IncomeRow>): IncomeRow {
    const income = this.incomes.get(id);
    if (!income) throw new Error('NOT_FOUND: income not found');
    const updated = { ...income, ...updates, updatedAt: getVietnamNow() };
    this.incomes.set(id, updated);
    return updated;
  }

  deleteIncome(id: string): boolean {
    return this.incomes.delete(id);
  }

  // Transfers
  createTransfer(data: Omit<TransferRow, 'createdAt'>): TransferRow {
    const now = getVietnamNow();
    const transfer = { ...data, createdAt: now };
    this.transfers.set(data.id, transfer);
    return transfer;
  }

  getTransfer(id: string): TransferRow | null {
    return this.transfers.get(id) ?? null;
  }

  getAllTransfers(options?: QueryOptions): QueryResult<TransferRow> {
    const rows = Array.from(this.transfers.values());
    return { rows, total: rows.length };
  }

  updateTransfer(id: string, updates: Partial<TransferRow>): TransferRow {
    const transfer = this.transfers.get(id);
    if (!transfer) throw new Error('NOT_FOUND: transfer not found');
    const updated = { ...transfer, ...updates, updatedAt: getVietnamNow() };
    this.transfers.set(id, updated);
    return updated;
  }

  // Ledger
  createLedgerEntry(data: LedgerEntryRow): LedgerEntryRow {
    this.ledgerEntries.set(data.id, data);
    return data;
  }

  getLedgerEntries(walletId: string): LedgerEntryRow[] {
    return Array.from(this.ledgerEntries.values()).filter((e) => e.walletId === walletId);
  }

  updateLedgerEntry(id: string, updates: Partial<LedgerEntryRow>): LedgerEntryRow {
    const entry = this.ledgerEntries.get(id);
    if (!entry) throw new Error('NOT_FOUND: ledger entry not found');
    const updated = { ...entry, ...updates };
    this.ledgerEntries.set(id, updated);
    return updated;
  }

  // Budgets
  createBudget(data: Omit<BudgetRow, 'createdAt' | 'updatedAt'>): BudgetRow {
    const now = getVietnamNow();
    const budget = { ...data, createdAt: now, updatedAt: now };
    this.budgets.set(data.id, budget);
    return budget;
  }

  getAllBudgets(): BudgetRow[] {
    return Array.from(this.budgets.values());
  }

  updateBudget(id: string, updates: Partial<BudgetRow>): BudgetRow {
    const budget = this.budgets.get(id);
    if (!budget) throw new Error('NOT_FOUND: budget not found');
    const updated = { ...budget, ...updates, updatedAt: getVietnamNow() };
    this.budgets.set(id, updated);
    return updated;
  }

  deleteBudget(id: string): boolean {
    return this.budgets.delete(id);
  }

  // Investments
  createInvestment(data: Omit<InvestmentRow, 'createdAt' | 'updatedAt'>): InvestmentRow {
    const now = getVietnamNow();
    const investment = { ...data, createdAt: now, updatedAt: now };
    this.investments.set(data.id, investment);
    return investment;
  }

  getAllInvestments(): InvestmentRow[] {
    return Array.from(this.investments.values());
  }

  updateInvestment(id: string, updates: Partial<InvestmentRow>): InvestmentRow {
    const investment = this.investments.get(id);
    if (!investment) throw new Error('NOT_FOUND: investment not found');
    const updated = { ...investment, ...updates, updatedAt: getVietnamNow() };
    this.investments.set(id, updated);
    return updated;
  }

  deleteInvestment(id: string): boolean {
    return this.investments.delete(id);
  }

  // Utility
  close(): void {
    // No-op for in-memory
  }

  transaction<T>(fn: () => T): T {
    return fn();
  }
}

// Singleton — all stores share one database instance
let dbInstance: InMemoryDatabase | null = null;

export function getSharedDb(): Database {
  if (!dbInstance) {
    dbInstance = new InMemoryDatabase();
  }
  return dbInstance;
}

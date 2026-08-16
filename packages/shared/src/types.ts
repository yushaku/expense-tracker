import { z } from 'zod';
import {
  BudgetPeriodSchema,
  BudgetSchema,
  CurrencySchema,
  ExpenseCategorySchema,
  ExpenseFilterSchema,
  ExpenseSchema,
  ExpenseSummarySchema,
  IncomeSchema,
  IncomeTypeSchema,
  LedgerEntrySchema,
  LedgerEntryTypeSchema,
  SyncMetadataSchema,
  SyncStatusSchema,
  TransactionStatusSchema,
  TransferSchema,
  WalletSchema,
  WalletTypeSchema,
  WalletWithBalanceSchema,
  AddExpenseInputSchema,
  AddIncomeInputSchema,
  CreateWalletInputSchema,
  SearchTransactionsInputSchema,
  SetBudgetInputSchema,
  TransferInputSchema,
  UpdateExpenseInputSchema,
  UpdateIncomeInputSchema,
  UpdateWalletInputSchema,
  VoidByIdInputSchema,
} from './schemas.js';

export type WalletType = z.infer<typeof WalletTypeSchema>;
export type ExpenseCategory = z.infer<typeof ExpenseCategorySchema>;
export type IncomeType = z.infer<typeof IncomeTypeSchema>;
export type TransactionStatus = z.infer<typeof TransactionStatusSchema>;
export type LedgerEntryType = z.infer<typeof LedgerEntryTypeSchema>;
export type BudgetPeriod = z.infer<typeof BudgetPeriodSchema>;
export type SupportedCurrency = z.infer<typeof CurrencySchema>;
export type SyncStatus = z.infer<typeof SyncStatusSchema>;

export type Wallet = z.infer<typeof WalletSchema>;
export type WalletWithBalance = z.infer<typeof WalletWithBalanceSchema>;
export type Expense = z.infer<typeof ExpenseSchema>;
export type Income = z.infer<typeof IncomeSchema>;
export type Transfer = z.infer<typeof TransferSchema>;
export type LedgerEntry = z.infer<typeof LedgerEntrySchema>;
export type Budget = z.infer<typeof BudgetSchema>;
export type ExpenseSummary = z.infer<typeof ExpenseSummarySchema>;
export type ExpenseFilter = z.infer<typeof ExpenseFilterSchema>;
export type SyncMetadata = z.infer<typeof SyncMetadataSchema>;

export type AddExpenseInput = z.infer<typeof AddExpenseInputSchema>;
export type UpdateExpenseInput = z.infer<typeof UpdateExpenseInputSchema>;
export type VoidByIdInput = z.infer<typeof VoidByIdInputSchema>;
export type AddIncomeInput = z.infer<typeof AddIncomeInputSchema>;
export type UpdateIncomeInput = z.infer<typeof UpdateIncomeInputSchema>;
export type TransferInput = z.infer<typeof TransferInputSchema>;
export type CreateWalletInput = z.infer<typeof CreateWalletInputSchema>;
export type UpdateWalletInput = z.infer<typeof UpdateWalletInputSchema>;
export type SearchTransactionsInput = z.infer<typeof SearchTransactionsInputSchema>;
export type SetBudgetInput = z.infer<typeof SetBudgetInputSchema>;

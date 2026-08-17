// packages/domain/src/index.ts
export { MoneyError, createMoney, addMoney, subtractMoney, formatMoney } from './money.js';
export type { Money } from './money.js';
export { WalletService } from './wallet.js';
export type {
  CreateWalletInput,
  PostExpenseInput,
  CreateTransferInput,
  CreditCardInfo,
} from './wallet.js';
export { InMemoryDatabase, getSharedDb } from './database.js';
export type { Wallet, LedgerEntry, Expense, Income, Category } from './database.js';

// packages/shared/src/database.ts
// Database interface and implementations for mobile (Expo) and desktop/MCP (better-sqlite3)

export interface QueryOptions {
  limit?: number;
  offset?: number;
}

export interface QueryResult<T> {
  rows: T[];
  total: number;
}

// Raw entity types for database operations
export interface WalletRow {
  id: string;
  name: string;
  type: string;
  currency: string;
  creditLimit: number;
  createdAt: string;
  updatedAt: string;
}

export interface ExpenseRow {
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

export interface IncomeRow {
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

export interface TransferRow {
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

export interface LedgerEntryRow {
  id: string;
  walletId: string;
  type: string;
  amount: number;
  refId: string;
  refType: string;
  date: string;
  status: string;
}

export interface BudgetRow {
  id: string;
  category: string;
  amount: number;
  currency: string;
  period: string;
  startDate: string;
  endDate: string | null;
  createdAt: string;
  updatedAt: string;
}

export interface InvestmentRow {
  id: string;
  name: string;
  type: string;
  currentValue: number;
  costBasis: number;
  quantity: number | null;
  unit: string | null;
  purchaseDate: string | null;
  currency: string;
  notes: string | null;
  createdAt: string;
  updatedAt: string;
}

export interface Database {
  // Wallets
  createWallet(data: Omit<WalletRow, 'createdAt' | 'updatedAt'>): WalletRow;
  getWallet(id: string): WalletRow | null;
  getAllWallets(): WalletRow[];
  updateWallet(id: string, updates: Partial<WalletRow>): WalletRow;
  deleteWallet(id: string): boolean;

  // Expenses
  createExpense(data: Omit<ExpenseRow, 'createdAt' | 'updatedAt'>): ExpenseRow;
  getExpense(id: string): ExpenseRow | null;
  getAllExpenses(options?: QueryOptions): QueryResult<ExpenseRow>;
  updateExpense(id: string, updates: Partial<ExpenseRow>): ExpenseRow;
  deleteExpense(id: string): boolean;

  // Incomes
  createIncome(data: Omit<IncomeRow, 'createdAt' | 'updatedAt'>): IncomeRow;
  getIncome(id: string): IncomeRow | null;
  getAllIncomes(options?: QueryOptions): QueryResult<IncomeRow>;
  updateIncome(id: string, updates: Partial<IncomeRow>): IncomeRow;
  deleteIncome(id: string): boolean;

  // Transfers
  createTransfer(data: Omit<TransferRow, 'createdAt'>): TransferRow;
  getTransfer(id: string): TransferRow | null;
  getAllTransfers(options?: QueryOptions): QueryResult<TransferRow>;

  // Ledger
  createLedgerEntry(data: LedgerEntryRow): LedgerEntryRow;
  getLedgerEntries(walletId: string): LedgerEntryRow[];

  // Budgets
  createBudget(data: Omit<BudgetRow, 'createdAt' | 'updatedAt'>): BudgetRow;
  getAllBudgets(): BudgetRow[];
  updateBudget(id: string, updates: Partial<BudgetRow>): BudgetRow;
  deleteBudget(id: string): boolean;

  // Investments
  createInvestment(data: Omit<InvestmentRow, 'createdAt' | 'updatedAt'>): InvestmentRow;
  getAllInvestments(): InvestmentRow[];
  updateInvestment(id: string, updates: Partial<InvestmentRow>): InvestmentRow;
  deleteInvestment(id: string): boolean;

  // Utility
  close(): void;
  transaction<T>(fn: () => T): T;
}

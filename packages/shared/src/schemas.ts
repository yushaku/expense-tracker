import { z } from 'zod';

/** ISO 8601 datetime (Date.parse-able). */
export const IsoDateTimeSchema = z
  .string()
  .min(1)
  .refine((s) => !Number.isNaN(Date.parse(s)), { message: 'Invalid ISO datetime' });

export const IdSchema = z.string().min(1);

// ── Enums (Phase 1 data model) ──────────────────────────────────────────────

export const WalletTypeSchema = z.enum(['cash', 'bank', 'ewallet', 'credit_card']);
export const ExpenseCategorySchema = z.enum([
  'food',
  'transport',
  'shopping',
  'entertainment',
  'healthcare',
  'education',
  'bills',
  'savings',
  'other',
]);
export const IncomeTypeSchema = z.enum([
  'salary',
  'freelance',
  'investment',
  'gift',
  'other',
]);
export const TransactionStatusSchema = z.enum(['active', 'voided']);
export const LedgerEntryTypeSchema = z.enum([
  'expense',
  'income',
  'transfer_out',
  'transfer_in',
  'opening_balance',
]);
export const BudgetPeriodSchema = z.enum(['weekly', 'monthly', 'yearly']);
export const CurrencySchema = z.enum(['VND', 'USD', 'EUR']);
export const SyncStatusSchema = z.enum(['synced', 'pending', 'error']);

// ── Money helpers ───────────────────────────────────────────────────────────

/** Strict positive amount (expense / income / transfer). */
export const PositiveAmountSchema = z.number().positive();

/** Non-negative (opening balance, credit limit). */
export const NonNegativeAmountSchema = z.number().nonnegative();

// ── Entities ────────────────────────────────────────────────────────────────

export const WalletSchema = z.object({
  id: IdSchema,
  name: z.string().min(1),
  type: WalletTypeSchema,
  currency: CurrencySchema,
  /** CC only; 0 for other wallet types. */
  creditLimit: NonNegativeAmountSchema.default(0),
  createdAt: IsoDateTimeSchema,
  updatedAt: IsoDateTimeSchema,
});

/** Wallet + derived balance (never stored). */
export const WalletWithBalanceSchema = WalletSchema.extend({
  balance: z.number(),
});

export const ExpenseSchema = z.object({
  id: IdSchema,
  amount: PositiveAmountSchema,
  currency: CurrencySchema,
  category: ExpenseCategorySchema,
  description: z.string().default(''),
  date: IsoDateTimeSchema,
  walletId: IdSchema,
  merchant: z.string().optional(),
  receiptImage: z.string().optional(),
  status: TransactionStatusSchema,
  clientRequestId: z.string().optional(),
  createdAt: IsoDateTimeSchema,
  updatedAt: IsoDateTimeSchema,
});

export const IncomeSchema = z.object({
  id: IdSchema,
  amount: PositiveAmountSchema,
  currency: CurrencySchema,
  source: z.string().default(''),
  description: z.string().default(''),
  date: IsoDateTimeSchema,
  walletId: IdSchema,
  type: IncomeTypeSchema,
  status: TransactionStatusSchema,
  clientRequestId: z.string().optional(),
  createdAt: IsoDateTimeSchema,
  updatedAt: IsoDateTimeSchema,
});

export const TransferSchema = z.object({
  id: IdSchema,
  fromWalletId: IdSchema,
  toWalletId: IdSchema,
  amount: PositiveAmountSchema,
  currency: CurrencySchema,
  date: IsoDateTimeSchema,
  note: z.string().optional(),
  status: TransactionStatusSchema,
  clientRequestId: z.string().optional(),
  createdAt: IsoDateTimeSchema,
  updatedAt: IsoDateTimeSchema,
});

export const LedgerEntrySchema = z.object({
  id: IdSchema,
  walletId: IdSchema,
  type: LedgerEntryTypeSchema,
  amount: z.number(), // signed in ledger semantics
  currency: CurrencySchema,
  /** FK to expense / income / transfer (pair). */
  refId: IdSchema,
  status: TransactionStatusSchema,
  date: IsoDateTimeSchema,
  createdAt: IsoDateTimeSchema,
});

export const BudgetSchema = z.object({
  id: IdSchema,
  category: z.union([ExpenseCategorySchema, z.literal('all')]),
  amount: PositiveAmountSchema,
  currency: CurrencySchema,
  period: BudgetPeriodSchema,
  startDate: IsoDateTimeSchema,
  endDate: IsoDateTimeSchema.nullable(),
});

export const ExpenseSummarySchema = z.object({
  totalAmount: z.number(),
  currency: CurrencySchema,
  period: z.object({
    start: IsoDateTimeSchema,
    end: IsoDateTimeSchema,
  }),
  byCategory: z.record(ExpenseCategorySchema, z.number()),
});

export const ExpenseFilterSchema = z.object({
  startDate: IsoDateTimeSchema.optional(),
  endDate: IsoDateTimeSchema.optional(),
  category: ExpenseCategorySchema.optional(),
  minAmount: NonNegativeAmountSchema.optional(),
  maxAmount: NonNegativeAmountSchema.optional(),
  search: z.string().optional(),
});

export const SyncMetadataSchema = z.object({
  deviceId: IdSchema,
  lastSyncedAt: IsoDateTimeSchema,
  status: SyncStatusSchema,
});

// ── Write / MCP input schemas (Phase 1) ─────────────────────────────────────

export const AddExpenseInputSchema = z.object({
  amount: PositiveAmountSchema,
  currency: CurrencySchema.default('VND'),
  category: ExpenseCategorySchema,
  description: z.string().optional(),
  date: IsoDateTimeSchema.optional(),
  walletId: IdSchema,
  merchant: z.string().optional(),
  dryRun: z.boolean().optional(),
  clientRequestId: z.string().min(1),
});

export const UpdateExpenseInputSchema = z.object({
  id: IdSchema,
  amount: PositiveAmountSchema.optional(),
  category: ExpenseCategorySchema.optional(),
  description: z.string().optional(),
  date: IsoDateTimeSchema.optional(),
});

export const VoidByIdInputSchema = z.object({
  id: IdSchema,
});

export const AddIncomeInputSchema = z.object({
  amount: PositiveAmountSchema,
  currency: CurrencySchema.default('VND'),
  source: z.string().optional(),
  description: z.string().optional(),
  date: IsoDateTimeSchema.optional(),
  walletId: IdSchema,
  type: IncomeTypeSchema.optional(),
  dryRun: z.boolean().optional(),
  clientRequestId: z.string().min(1),
});

export const UpdateIncomeInputSchema = z.object({
  id: IdSchema,
  amount: PositiveAmountSchema.optional(),
  source: z.string().optional(),
  description: z.string().optional(),
  date: IsoDateTimeSchema.optional(),
});

export const TransferInputSchema = z
  .object({
    fromWalletId: IdSchema,
    toWalletId: IdSchema,
    amount: PositiveAmountSchema,
    date: IsoDateTimeSchema.optional(),
    note: z.string().optional(),
    dryRun: z.boolean().optional(),
    clientRequestId: z.string().min(1),
  })
  .refine((v) => v.fromWalletId !== v.toWalletId, {
    message: 'fromWalletId must differ from toWalletId',
    path: ['toWalletId'],
  });

export const CreateWalletInputSchema = z
  .object({
    name: z.string().min(1),
    type: WalletTypeSchema,
    currency: CurrencySchema.default('VND'),
    creditLimit: NonNegativeAmountSchema.optional(),
    openingBalance: NonNegativeAmountSchema.default(0),
  })
  .superRefine((v, ctx) => {
    if (v.type === 'credit_card') {
      if (v.creditLimit === undefined || v.creditLimit <= 0) {
        ctx.addIssue({
          code: z.ZodIssueCode.custom,
          message: 'creditLimit > 0 required for credit_card',
          path: ['creditLimit'],
        });
      }
    }
  });

export const UpdateWalletInputSchema = z.object({
  id: IdSchema,
  name: z.string().min(1).optional(),
  creditLimit: PositiveAmountSchema.optional(),
});

export const SearchTransactionsInputSchema = z.object({
  from: IsoDateTimeSchema.optional(),
  to: IsoDateTimeSchema.optional(),
  walletId: IdSchema.optional(),
  category: ExpenseCategorySchema.optional(),
  type: z.enum(['expense', 'income']).optional(),
  text: z.string().optional(),
  includeVoided: z.boolean().optional(),
  limit: z.number().int().positive().max(500).default(50),
  offset: z.number().int().nonnegative().default(0),
});

export const SetBudgetInputSchema = z.object({
  category: z.union([ExpenseCategorySchema, z.literal('all')]),
  amount: PositiveAmountSchema,
  currency: CurrencySchema.default('VND'),
  period: BudgetPeriodSchema,
});

// ── Verify helpers ──────────────────────────────────────────────────────────

export type ParseResult<T> =
  | { success: true; data: T }
  | { success: false; error: z.ZodError };

export function parseWithSchema<T>(
  schema: z.ZodType<T>,
  data: unknown
): T {
  return schema.parse(data);
}

export function safeParseWithSchema<T>(
  schema: z.ZodType<T>,
  data: unknown
): ParseResult<T> {
  const result = schema.safeParse(data);
  if (result.success) {
    return { success: true, data: result.data };
  }
  return { success: false, error: result.error };
}

/** Flatten Zod issues → stable API/MCP error payload. */
export function formatZodError(error: z.ZodError): {
  code: 'VALIDATION_ERROR';
  issues: Array<{ path: string; message: string }>;
} {
  return {
    code: 'VALIDATION_ERROR',
    issues: error.issues.map((i) => ({
      path: i.path.join('.') || '(root)',
      message: i.message,
    })),
  };
}
// packages/shared/src/index.ts

export * from './schemas.js';
export * from './types.js';
export * from './database.js';
export * from './ledger.js';
export * from './utils.js';
export * from './inMemoryDatabase.js';

import type { ExpenseCategory, SupportedCurrency } from './types.js';

export const SUPPORTED_CURRENCIES = ['VND'] as const satisfies readonly SupportedCurrency[];
export const DEFAULT_CURRENCY: SupportedCurrency = 'VND';

export const CATEGORY_LABELS: Record<ExpenseCategory, string> = {
  food: 'Ăn uống',
  transport: 'Di chuyển',
  shopping: 'Mua sắm',
  entertainment: 'Giải trí',
  healthcare: 'Y tế',
  education: 'Giáo dục',
  bills: 'Hóa đơn',
  savings: 'Tiết kiệm',
  other: 'Khác',
};

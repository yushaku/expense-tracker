export * from './schemas.js';
export * from './types.js';

import type { ExpenseCategory, SupportedCurrency } from './types.js';

export const SUPPORTED_CURRENCIES = ['VND', 'USD', 'EUR'] as const satisfies readonly SupportedCurrency[];

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

export function formatCurrency(amount: number, currency: string): string {
  return new Intl.NumberFormat('vi-VN', {
    style: 'currency',
    currency,
    minimumFractionDigits: 0,
    maximumFractionDigits: 0,
  }).format(amount);
}

export function generateId(): string {
  return Date.now().toString(36) + Math.random().toString(36).slice(2, 11);
}

export function getMonthRange(date: Date): { start: string; end: string } {
  const start = new Date(date.getFullYear(), date.getMonth(), 1);
  const end = new Date(date.getFullYear(), date.getMonth() + 1, 0, 23, 59, 59);
  return { start: start.toISOString(), end: end.toISOString() };
}

// packages/shared/src/utils.ts

/**
 * Generate a UUID v4 (cryptographically random).
 */
export function generateId(): string {
  return crypto.randomUUID();
}

/**
 * Get current time as ISO string in Asia/Ho_Chi_Minh timezone (UTC+7).
 * Vietnam does not observe DST, so offset is always +7.
 */
export function getVietnamNow(): string {
  const now = new Date();
  const offsetMs = 7 * 60 * 60 * 1000;
  const vnTime = new Date(now.getTime() + offsetMs);
  return vnTime.toISOString();
}

/**
 * Convert a Date to Asia/Ho_Chi_Minh ISO string.
 */
export function toVietnamISO(date: Date): string {
  const offsetMs = 7 * 60 * 60 * 1000;
  return new Date(date.getTime() + offsetMs).toISOString();
}

/**
 * Format money using BigInt minor units (vi-VN locale).
 * Re-export from @expense/domain for backward compatibility.
 */
export { formatMoney } from '@expense/domain';

/**
 * @deprecated Use formatMoney from @expense/domain instead.
 * This function uses JS number which loses precision for large amounts.
 */
export function formatCurrency(amount: number, currency: string): string {
  return new Intl.NumberFormat('vi-VN', {
    style: 'currency',
    currency,
    minimumFractionDigits: 0,
    maximumFractionDigits: 0,
  }).format(amount);
}

/**
 * Get month range (start and end ISO strings) in Vietnam timezone.
 */
export function getMonthRange(date: Date): { start: string; end: string } {
  const year = date.getFullYear();
  const month = date.getMonth();
  const start = new Date(year, month, 1);
  const end = new Date(year, month + 1, 0, 23, 59, 59);
  return { start: toVietnamISO(start), end: toVietnamISO(end) };
}

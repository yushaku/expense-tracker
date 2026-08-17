// packages/shared/src/utils.ts

/**
 * Generate a unique ID (timestamp + random).
 */
export function generateId(): string {
  return Date.now().toString(36) + Math.random().toString(36).substr(2, 9);
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
 * Format currency using vi-VN locale.
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

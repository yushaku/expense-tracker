// packages/ui/src/utils/format.ts
// Shared formatting utilities (v3: BigInt money)

/**
 * Format minor units BigInt to display string with thousands separator.
 * VND has scale 0, USD/EUR have scale 2.
 */
export function formatMinorUnits(minorUnits: bigint, currency: string): string {
  const scale = getScale(currency);
  const isNegative = minorUnits < 0n;
  const absMinor = isNegative ? -minorUnits : minorUnits;

  const str = absMinor.toString().padStart(scale + 1, '0');

  let formatted: string;
  if (scale === 0) {
    formatted = str;
  } else {
    const intPart = str.slice(0, -scale);
    const fracPart = str.slice(-scale);
    formatted = `${intPart}.${fracPart}`;
  }

  // Add thousands separator
  if (scale === 0) {
    formatted = formatted.replace(/\B(?=(\d{3})+(?!\d))/g, ',');
  } else {
    const parts = formatted.split('.');
    parts[0] = parts[0].replace(/\B(?=(\d{3})+(?!\d))/g, ',');
    formatted = parts.join('.');
  }

  return isNegative ? `-${formatted}` : formatted;
}

function getScale(currency: string): number {
  const scales: Record<string, number> = {
    VND: 0,
    JPY: 0,
    KRW: 0,
    USD: 2,
    EUR: 2,
    GBP: 2,
    THB: 2,
  };
  return scales[currency] ?? 2;
}

/**
 * Parse decimal string input to minor units BigInt.
 * "500000" → 500000n (VND), "123.45" → 12345n (USD)
 */
export function parseToMinorUnits(amount: string, currency: string): bigint {
  const scale = getScale(currency);
  const regex = /^\d+(\.\d+)?$/;
  if (!regex.test(amount)) {
    throw new Error('INVALID_AMOUNT');
  }

  if (scale === 0) {
    return BigInt(amount);
  }

  const [intPart, fracPartRaw = ''] = amount.split('.');
  const fracPart = fracPartRaw.padEnd(scale, '0').slice(0, scale);
  return BigInt(intPart) * BigInt(10 ** scale) + BigInt(fracPart);
}

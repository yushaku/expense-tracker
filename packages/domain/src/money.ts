// packages/domain/src/money.ts
// Money type — uses integer minor units (bigint), never JS number/float

export interface Money {
  minorUnits: bigint;
  currency: string;
}

export class MoneyError extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'MoneyError';
  }
}

// ISO 4217 currency scales (number of decimal places)
const CURRENCY_SCALE: Record<string, number> = {
  VND: 0,
  USD: 2,
  EUR: 2,
  JPY: 0,
  GBP: 2,
};

function getScale(currency: string): number {
  const scale = CURRENCY_SCALE[currency];
  if (scale === undefined) {
    throw new MoneyError(`UNSUPPORTED_CURRENCY: ${currency}`);
  }
  return scale;
}

export function createMoney(amount: string, currency: string): Money {
  const scale = getScale(currency);

  // Validate format
  const regex = /^\d+(\.\d+)?$/;
  if (!regex.test(amount)) {
    throw new MoneyError('INVALID_AMOUNT: must be a non-negative decimal number');
  }

  // Check for zero
  if (amount === '0' || amount === '0.0' || amount === '0.00') {
    throw new MoneyError('INVALID_AMOUNT: must be greater than zero');
  }

  // Parse to minor units
  let minorUnits: bigint;
  if (scale === 0) {
    // No decimal part allowed
    if (amount.includes('.')) {
      throw new MoneyError('INVALID_AMOUNT: no decimal places allowed for ' + currency);
    }
    minorUnits = BigInt(amount);
  } else {
    const [intPart, fracPartRaw = ''] = amount.split('.');
    const fracPart = fracPartRaw.padEnd(scale, '0').slice(0, scale);
    minorUnits = BigInt(intPart) * BigInt(10 ** scale) + BigInt(fracPart);
  }

  if (minorUnits <= 0n) {
    throw new MoneyError('INVALID_AMOUNT: must be greater than zero');
  }

  return { minorUnits, currency };
}

export function addMoney(a: Money, b: Money): Money {
  if (a.currency !== b.currency) {
    throw new MoneyError('CURRENCY_MISMATCH');
  }
  return { minorUnits: a.minorUnits + b.minorUnits, currency: a.currency };
}

export function subtractMoney(a: Money, b: Money): Money {
  if (a.currency !== b.currency) {
    throw new MoneyError('CURRENCY_MISMATCH');
  }
  return { minorUnits: a.minorUnits - b.minorUnits, currency: a.currency };
}

export function formatMoney(m: Money): string {
  const scale = getScale(m.currency);
  const isNegative = m.minorUnits < 0n;
  const absMinor = isNegative ? -m.minorUnits : m.minorUnits;

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
  formatted = formatted.replace(/\B(?=(\d{3})+(?!\d))/g, ',');

  return isNegative ? `-${formatted}` : formatted;
}

// packages/domain/tests/money.test.ts
import { describe, it, expect } from 'vitest';
import { Money, createMoney, addMoney, subtractMoney, formatMoney } from '../src/money.js';

describe('Money', () => {
  describe('createMoney', () => {
    it('creates money from decimal string with currency', () => {
      const m = createMoney('50000', 'VND');
      expect(m).toEqual({ minorUnits: 50000n, currency: 'VND' });
    });

    it('parses decimal string with fractional part', () => {
      const m = createMoney('123.45', 'USD');
      expect(m).toEqual({ minorUnits: 12345n, currency: 'USD' });
    });

    it('throws on invalid decimal string', () => {
      expect(() => createMoney('abc', 'VND')).toThrow();
    });

    it('throws on negative amount', () => {
      expect(() => createMoney('-100', 'VND')).toThrow();
    });

    it('throws on zero amount', () => {
      expect(() => createMoney('0', 'VND')).toThrow();
    });
  });

  describe('addMoney', () => {
    it('adds two money values of same currency', () => {
      const a = createMoney('50000', 'VND');
      const b = createMoney('25000', 'VND');
      const result = addMoney(a, b);
      expect(result).toEqual({ minorUnits: 75000n, currency: 'VND' });
    });

    it('throws when adding different currencies', () => {
      const a = createMoney('100', 'VND');
      const b = createMoney('100', 'USD');
      expect(() => addMoney(a, b)).toThrow('CURRENCY_MISMATCH');
    });
  });

  describe('subtractMoney', () => {
    it('subtracts two money values of same currency', () => {
      const a = createMoney('75000', 'VND');
      const b = createMoney('25000', 'VND');
      const result = subtractMoney(a, b);
      expect(result).toEqual({ minorUnits: 50000n, currency: 'VND' });
    });

    it('throws when subtracting different currencies', () => {
      const a = createMoney('100', 'VND');
      const b = createMoney('100', 'USD');
      expect(() => subtractMoney(a, b)).toThrow('CURRENCY_MISMATCH');
    });
  });

  describe('formatMoney', () => {
    it('formats VND with no decimals', () => {
      const m = createMoney('50000', 'VND');
      expect(formatMoney(m)).toBe('50,000');
    });

    it('formats USD with 2 decimals', () => {
      const m = createMoney('123.45', 'USD');
      expect(formatMoney(m)).toBe('123.45');
    });
  });
});

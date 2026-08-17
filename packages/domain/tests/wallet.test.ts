// packages/domain/tests/wallet.test.ts
import { describe, it, expect } from 'vitest';
import { WalletService } from '../src/wallet.js';
import { InMemoryDatabase } from '../src/database.js';
import { createMoney } from '../src/money.js';

describe('WalletService', () => {
  describe('createWallet', () => {
    it('creates a cash wallet with no opening balance', () => {
      const db = new InMemoryDatabase();
      const service = new WalletService(db);
      const wallet = service.createWallet({ name: 'Cash', type: 'cash', currency: 'VND' });

      expect(wallet.name).toBe('Cash');
      expect(wallet.type).toBe('cash');
      expect(service.getBalance(wallet.id)).toBe(0n);
      expect(wallet.creditLimitMinor).toBe(0n);
    });

    it('creates a wallet with opening balance and ledger entry', () => {
      const db = new InMemoryDatabase();
      const service = new WalletService(db);
      const wallet = service.createWallet({
        name: 'Bank',
        type: 'bank',
        currency: 'VND',
        openingBalance: 1000000n,
      });

      expect(service.getBalance(wallet.id)).toBe(1000000n);
      const entries = db.getLedgerEntries(wallet.id);
      expect(entries).toHaveLength(1);
      expect(entries[0].entryKind).toBe('opening_balance');
      expect(entries[0].signedMinor).toBe(1000000n);
    });

    it('creates a credit card wallet with credit limit', () => {
      const db = new InMemoryDatabase();
      const service = new WalletService(db);
      const wallet = service.createWallet({
        name: 'Credit Card',
        type: 'credit_card',
        currency: 'VND',
        creditLimitMinor: 50000000n,
      });

      expect(wallet.type).toBe('credit_card');
      expect(wallet.creditLimitMinor).toBe(50000000n);
      expect(service.getBalance(wallet.id)).toBe(0n);
    });

    it('throws if credit card has no credit limit', () => {
      const db = new InMemoryDatabase();
      const service = new WalletService(db);
      expect(() =>
        service.createWallet({ name: 'Bad CC', type: 'credit_card', currency: 'VND' }),
      ).toThrow();
    });
  });

  describe('getCreditCardInfo', () => {
    it('calculates debt and available credit', () => {
      const db = new InMemoryDatabase();
      const service = new WalletService(db);
      const cc = service.createWallet({
        name: 'Credit Card',
        type: 'credit_card',
        currency: 'VND',
        creditLimitMinor: 50000000n,
      });
      const bank = service.createWallet({
        name: 'Bank',
        type: 'bank',
        currency: 'VND',
        openingBalance: 10000000n,
      });

      // Simulate spending 10M on credit card
      service.postExpense({
        walletId: cc.id,
        amount: createMoney('10000000', 'VND'),
        categoryId: 'food',
      });

      // Simulate paying 5M to credit card
      service.createTransfer({
        fromWalletId: bank.id,
        toWalletId: cc.id,
        amount: createMoney('5000000', 'VND'),
      });

      const info = service.getCreditCardInfo(cc.id);
      expect(info.debt).toBe(5000000n); // net: 10M expense - 5M payment
      expect(info.payments).toBe(5000000n);
      expect(info.available).toBe(45000000n); // 50M - 5M
      expect(info.creditLimit).toBe(50000000n);
    });
  });
});

// apps/mobile/app/transactions/index.tsx
// Transactions list — all expenses and incomes grouped by date

import React, { useState } from 'react';
import { ScrollView, Text, XStack, YStack, Input, Card } from '@expense/ui';
import { Chip } from '@expense/ui';
import { ListItem } from '@expense/ui';
import { MaterialCommunityIcons } from '@expo/vector-icons';
import { useExpenseStore } from '../../src/stores/expenseStore';
import { useIncomeStore } from '../../src/stores/incomeStore';
import { useWalletStore } from '../../src/stores/walletStore';
import { useRouter } from 'expo-router';
import { formatMoney } from '@expense/domain';

type FilterType = 'all' | 'income' | 'expense';

interface TransactionItem {
  id: string;
  type: 'expense' | 'income';
  categoryId?: string;
  amountMinor: bigint;
  currency: string;
  description?: string;
  occurredAtUtc: string;
  status: 'active' | 'voided';
  walletId: string;
}

export default function TransactionsScreen() {
  const router = useRouter();
  const { expenses, loadExpenses } = useExpenseStore();
  const { incomes, loadIncomes } = useIncomeStore();
  const { wallets, loadWallets } = useWalletStore();
  const [filter, setFilter] = useState<FilterType>('all');
  const [search, setSearch] = useState('');

  React.useEffect(() => {
    loadExpenses();
    loadIncomes();
    loadWallets();
  }, []);

  // Combine and filter
  const allTransactions: TransactionItem[] = [
    ...expenses.map((e) => ({
      id: e.id,
      type: 'expense' as const,
      categoryId: e.categoryId,
      amountMinor: e.amountMinor,
      currency: e.currency,
      description: e.description,
      occurredAtUtc: e.occurredAtUtc,
      status: e.status,
      walletId: e.walletId,
    })),
    ...incomes.map((i) => ({
      id: i.id,
      type: 'income' as const,
      categoryId: i.categoryId,
      amountMinor: i.amountMinor,
      currency: i.currency,
      description: i.description,
      occurredAtUtc: i.occurredAtUtc,
      status: i.status,
      walletId: i.walletId,
    })),
  ];

  // Sort by date desc
  allTransactions.sort((a, b) => b.occurredAtUtc.localeCompare(a.occurredAtUtc));

  // Filter
  const filtered = allTransactions.filter((t) => {
    if (filter !== 'all' && t.type !== filter) return false;
    if (search) {
      const q = search.toLowerCase();
      if (
        !t.description?.toLowerCase().includes(q) &&
        t.categoryId?.toLowerCase() !== q
      ) {
        return false;
      }
    }
    return true;
  });

  // Group by date
  const grouped = new Map<string, TransactionItem[]>();
  for (const tx of filtered) {
    const date = tx.occurredAtUtc.slice(0, 10);
    if (!grouped.has(date)) grouped.set(date, []);
    grouped.get(date)!.push(tx);
  }

  return (
    <ScrollView flex={1} backgroundColor="$background">
      <YStack gap="$4" padding="$4">
        {/* Header */}
        <Text fontSize="$xl" fontWeight="bold">
          Giao dịch
        </Text>

        {/* Search */}
        <Input
          placeholder="Tìm kiếm..."
          value={search}
          onChangeText={setSearch}
        />

        {/* Filter Chips */}
        <XStack gap="$2" flexWrap="wrap">
          <Chip
            label="Tất cả"
            variant={filter === 'all' ? 'primary' : 'default'}
            onPress={() => setFilter('all')}
          />
          <Chip
            label="Thu nhập"
            variant={filter === 'income' ? 'income' : 'default'}
            onPress={() => setFilter('income')}
          />
          <Chip
            label="Chi tiêu"
            variant={filter === 'expense' ? 'expense' : 'default'}
            onPress={() => setFilter('expense')}
          />
        </XStack>

        {/* Transactions List */}
        {Array.from(grouped.entries()).map(([date, txs]) => (
          <YStack key={date} gap="$2">
            <Text fontSize="$sm" color="$muted" fontWeight="600">
              {new Date(date).toLocaleDateString('vi-VN', {
                day: '2-digit',
                month: '2-digit',
                year: 'numeric',
              })}
            </Text>
            <YStack gap="$1">
              {txs.map((tx) => {
                const wallet = wallets.find((w) => w.id === tx.walletId);
                return (
                  <Card
                    key={tx.id}
                    pressable
                    onPress={() =>
                      router.push(`/${tx.type}s/${tx.id}` as any)
                    }
                    padding="$3"
                  >
                    <XStack
                      justifyContent="space-between"
                      alignItems="center"
                    >
                      <XStack gap="$3" alignItems="center">
                        <MaterialCommunityIcons
                          name={tx.type === 'expense' ? 'arrow-up' : 'arrow-down'}
                          size={20}
                          color={
                            tx.type === 'expense'
                              ? '#e78284'
                              : '#a6d189'
                          }
                        />
                        <YStack>
                          <Text fontSize="$sm" fontWeight="500">
                            {tx.description || (tx.type === 'expense' ? 'Chi tiêu' : 'Thu nhập')}
                          </Text>
                          <Text fontSize="$xs" color="$muted">
                            {wallet?.name ?? 'Không xác định'}
                          </Text>
                        </YStack>
                      </XStack>
                      <Text
                        fontSize="$sm"
                        fontWeight="600"
                        color={
                          tx.type === 'expense'
                            ? '$expense'
                            : '$income'
                        }
                      >
                        {tx.type === 'expense' ? '-' : '+'}
                        {formatMoney({
                          minorUnits: tx.amountMinor >= 0n ? tx.amountMinor : -tx.amountMinor,
                          currency: tx.currency,
                        })}
                      </Text>
                    </XStack>
                  </Card>
                );
              })}
            </YStack>
          </YStack>
        ))}

        {grouped.size === 0 && (
          <YStack padding="$8" alignItems="center">
            <Text color="$muted">Không có giao dịch nào</Text>
          </YStack>
        )}
      </YStack>
    </ScrollView>
  );
}

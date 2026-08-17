// apps/mobile/src/components/expenses/ExpenseList.tsx
// List of expenses with search/filter

import React from 'react';
import { YStack, Text, Input, XStack } from '@expense/ui';
import type { Expense } from '@expense/shared';
import { ExpenseCard } from './ExpenseCard';
import { ExpenseFilters } from './ExpenseFilters';

interface ExpenseListProps {
  expenses: Expense[];
  loading?: boolean;
  searchQuery: string;
  onSearchChange: (query: string) => void;
  onExpensePress?: (expense: Expense) => void;
  onFilterChange: (filters: any) => void;
  filters: any;
  walletMap?: Record<string, string>;
}

export function ExpenseList({
  expenses,
  loading,
  searchQuery,
  onSearchChange,
  onExpensePress,
  onFilterChange,
  filters,
  walletMap,
}: ExpenseListProps) {
  if (loading) {
    return (
      <YStack padding="$4">
        <Text color="$onSurfaceVariant">Đang tải...</Text>
      </YStack>
    );
  }

  if (expenses.length === 0) {
    return (
      <YStack padding="$4" gap="$2" alignItems="center">
        <Text color="$onSurfaceVariant" textAlign="center">
          Chưa có chi tiêu nào.
        </Text>
        <Text color="$onSurfaceVariant" textAlign="center" fontSize="$sm">
          Nhấn + để thêm chi tiêu đầu tiên.
        </Text>
      </YStack>
    );
  }

  return (
    <YStack gap="$2" flex={1}>
      {/* Search Input */}
      <XStack paddingHorizontal="$4" paddingTop="$2">
        <Input
          flex={1}
          value={searchQuery}
          onChangeText={onSearchChange}
          placeholder="Tìm kiếm chi tiêu..."
          iconLeft={<Text fontSize="$sm">🔍</Text>}
        />
      </XStack>

      {/* Filters */}
      <ExpenseFilters filters={filters} onFilterChange={onFilterChange} />

      {/* Expense List */}
      <YStack gap="$2" paddingHorizontal="$4" paddingBottom="$12">
        {expenses.map((expense) => (
          <ExpenseCard
            key={expense.id}
            expense={expense}
            onPress={onExpensePress ? () => onExpensePress(expense) : undefined}
            walletName={walletMap ? walletMap[expense.walletId] : undefined}
          />
        ))}
      </YStack>
    </YStack>
  );
}

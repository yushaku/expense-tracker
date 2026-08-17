// apps/mobile/app/expenses/index.tsx
// Expense list screen

import React, { useEffect, useState, useMemo } from 'react';
import { YStack, Text } from '@expense/ui';
import { useExpenseStore } from '@/src/stores/expenseStore';
import { useWalletStore } from '@/src/stores/walletStore';
import { ExpenseList } from '@/src/components/expenses/ExpenseList';
import { FAB } from '@expense/ui';
import { useRouter } from 'expo-router';
import { MaterialCommunityIcons } from '@expo/vector-icons';

export default function ExpensesScreen() {
  const router = useRouter();
  const { filteredExpenses, loading, error, loadExpenses, filters, setFilters } = useExpenseStore();
  const { wallets, loadWallets } = useWalletStore();
  const [searchQuery, setSearchQuery] = useState('');

  useEffect(() => {
    loadExpenses();
    loadWallets();
  }, []);

  const walletMap = useMemo(() => {
    const map: Record<string, string> = {};
    wallets.forEach((w) => {
      map[w.id] = w.name;
    });
    return map;
  }, [wallets]);

  // Apply search query to filters
  const handleSearchChange = (query: string) => {
    setSearchQuery(query);
    setFilters({ ...filters, search: query });
  };

  const handleFilterChange = (newFilters: any) => {
    setFilters(newFilters);
  };

  const handleExpensePress = (expense: any) => {
    router.push(`/expenses/${expense.id}` as any);
  };

  return (
    <YStack flex={1} backgroundColor="$background">
      <YStack padding="$4" paddingBottom="$2">
        <Text fontSize="$2xl" fontWeight="bold">
          Chi tiêu
        </Text>
      </YStack>

      {error && (
        <Text color="$error" fontSize="$sm" paddingHorizontal="$4">
          {error}
        </Text>
      )}

      <ExpenseList
        expenses={filteredExpenses()}
        loading={loading}
        searchQuery={searchQuery}
        onSearchChange={handleSearchChange}
        onExpensePress={handleExpensePress}
        onFilterChange={handleFilterChange}
        filters={filters}
        walletMap={walletMap}
      />

      <FAB
        icon={<MaterialCommunityIcons name="plus" size={24} color="white" />}
        onPress={() => router.push('/expenses/new' as any)}
        ariaLabel="Thêm chi tiêu"
      />
    </YStack>
  );
}

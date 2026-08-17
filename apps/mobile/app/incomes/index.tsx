// apps/mobile/app/incomes/index.tsx
// Income list screen

import React, { useEffect, useState, useMemo } from 'react';
import { YStack, Text } from '@expense/ui';
import { useIncomeStore } from '../../src/stores/incomeStore';
import { useWalletStore } from '../../src/stores/walletStore';
import { IncomeList } from '../../src/components/incomes/IncomeList';
import { FAB } from '@expense/ui';
import { useRouter } from 'expo-router';
import { MaterialCommunityIcons } from '@expo/vector-icons';

export default function IncomesScreen() {
  const router = useRouter();
  const { filteredIncomes, loading, error, loadIncomes, filters, setFilters } =
    useIncomeStore();
  const { wallets, loadWallets } = useWalletStore();
  const [searchQuery, setSearchQuery] = useState('');

  useEffect(() => {
    loadIncomes();
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

  const handleIncomePress = (income: any) => {
    router.push(`/incomes/${income.id}` as any);
  };

  return (
    <YStack flex={1} backgroundColor="$background">
      <YStack padding="$4" paddingBottom="$2">
        <Text fontSize="$2xl" fontWeight="bold">
          Thu nhập
        </Text>
      </YStack>

      {error && (
        <Text color="$error" fontSize="$sm" paddingHorizontal="$4">
          {error}
        </Text>
      )}

      <IncomeList
        incomes={filteredIncomes()}
        loading={loading}
        searchQuery={searchQuery}
        onSearchChange={handleSearchChange}
        onIncomePress={handleIncomePress}
        onFilterChange={handleFilterChange}
        filters={filters}
        walletMap={walletMap}
      />

      <FAB
        icon={<MaterialCommunityIcons name="plus" size={24} color="white" />}
        onPress={() => router.push('/incomes/new' as any)}
        ariaLabel="Thêm thu nhập"
      />
    </YStack>
  );
}
// apps/mobile/src/components/incomes/IncomeList.tsx
// List of incomes with search/filter

import React from 'react';
import { YStack, Text, Input, XStack, ScrollView } from '@expense/ui';
import type { Income } from '@expense/shared';
import { Chip, ChipText } from '@expense/ui';
import { IncomeCard } from './IncomeCard';
import type { IncomeFilters } from '../../stores/incomeStore';
import { INCOME_TYPE_LABELS } from '../../stores/incomeStore';
import type { IncomeType } from '@expense/shared';

interface IncomeListProps {
  incomes: Income[];
  loading?: boolean;
  searchQuery: string;
  onSearchChange: (query: string) => void;
  onIncomePress?: (income: Income) => void;
  onFilterChange: (filters: IncomeFilters) => void;
  filters: IncomeFilters;
  walletMap?: Record<string, string>;
}

const STATUS_OPTIONS = [
  { value: 'all', label: 'Tất cả' },
  { value: 'active', label: 'Hoạt động' },
  { value: 'voided', label: 'Đã hủy' },
];

const TYPE_OPTIONS: (IncomeType | 'all')[] = [
  'all',
  'salary',
  'freelance',
  'investment',
  'gift',
  'other',
];

export function IncomeList({
  incomes,
  loading,
  searchQuery,
  onSearchChange,
  onIncomePress,
  onFilterChange,
  filters,
  walletMap,
}: IncomeListProps) {
  if (loading) {
    return (
      <YStack padding="$4">
        <Text color="$onSurfaceVariant">Đang tải...</Text>
      </YStack>
    );
  }

  if (incomes.length === 0) {
    return (
      <YStack padding="$4" gap="$2" alignItems="center">
        <Text color="$onSurfaceVariant" textAlign="center">
          Chưa có thu nhập nào.
        </Text>
        <Text color="$onSurfaceVariant" textAlign="center" fontSize="$sm">
          Nhấn + để thêm thu nhập đầu tiên.
        </Text>
      </YStack>
    );
  }

  const getTypeLabel = (type: IncomeType | 'all') => {
    if (type === 'all') return 'Tất cả';
    return INCOME_TYPE_LABELS[type];
  };

  return (
    <YStack gap="$2" flex={1}>
      {/* Search Input */}
      <XStack paddingHorizontal="$4" paddingTop="$2">
        <Input
          flex={1}
          value={searchQuery}
          onChangeText={onSearchChange}
          placeholder="Tìm kiếm thu nhập..."
          iconLeft={<Text fontSize="$sm">🔍</Text>}
        />
      </XStack>

      {/* Filters */}
      <XStack paddingHorizontal="$4" paddingVertical="$2" gap="$2">
        <ScrollView horizontal showsHorizontalScrollIndicator={false}>
          <XStack gap="$2">
            {/* Status Filter */}
            {STATUS_OPTIONS.map((status) => (
              <Chip
                key={status.value}
                selected={
                  filters.status === status.value || (!filters.status && status.value === 'all')
                }
                onPress={() => onFilterChange({ ...filters, status: status.value as any })}
              >
                <ChipText
                  selected={
                    filters.status === status.value || (!filters.status && status.value === 'all')
                  }
                >
                  {status.label}
                </ChipText>
              </Chip>
            ))}

            {/* Divider */}
            <Text color="$onSurfaceVariant" fontSize="$sm" lineHeight={32}>
              |
            </Text>

            {/* Type Filter */}
            {TYPE_OPTIONS.map((type) => (
              <Chip
                key={type}
                selected={filters.type === type || (!filters.type && type === 'all')}
                onPress={() => onFilterChange({ ...filters, type })}
              >
                <ChipText selected={filters.type === type || (!filters.type && type === 'all')}>
                  {getTypeLabel(type)}
                </ChipText>
              </Chip>
            ))}
          </XStack>
        </ScrollView>
      </XStack>

      {/* Income List */}
      <YStack gap="$2" paddingHorizontal="$4" paddingBottom="$12">
        {incomes.map((income) => (
          <IncomeCard
            key={income.id}
            income={income}
            onPress={onIncomePress ? () => onIncomePress(income) : undefined}
            walletName={walletMap ? walletMap[income.walletId] : undefined}
          />
        ))}
      </YStack>
    </YStack>
  );
}

// apps/mobile/src/components/expenses/ExpenseFilters.tsx
// Filter chips for expenses

import React from 'react';
import { XStack, Text, ScrollView } from '@expense/ui';
import { Chip, ChipText } from '@expense/ui';
import { ExpenseCategory, CATEGORY_LABELS } from '@expense/shared';

interface ExpenseFiltersProps {
  filters: {
    category?: ExpenseCategory | 'all';
    status?: 'active' | 'voided' | 'all';
  };
  onFilterChange: (filters: any) => void;
}

const STATUS_OPTIONS = [
  { value: 'all', label: 'Tất cả' },
  { value: 'active', label: 'Hoạt động' },
  { value: 'voided', label: 'Đã hủy' },
];

export function ExpenseFilters({ filters, onFilterChange }: ExpenseFiltersProps) {
  const categories: (ExpenseCategory | 'all')[] = [
    'all',
    'food',
    'transport',
    'shopping',
    'entertainment',
    'healthcare',
    'education',
    'bills',
    'savings',
    'other',
  ];

  const getCategoryLabel = (cat: ExpenseCategory | 'all') => {
    if (cat === 'all') return 'Tất cả';
    return CATEGORY_LABELS[cat];
  };

  return (
    <XStack paddingHorizontal="$4" paddingVertical="$2" gap="$2">
      <ScrollView horizontal showsHorizontalScrollIndicator={false}>
        <XStack gap="$2">
          {/* Status Filter */}
          {STATUS_OPTIONS.map((status) => (
            <Chip
              key={status.value}
              selected={filters.status === status.value || (!filters.status && status.value === 'all')}
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

          {/* Category Filter */}
          {categories.map((cat) => (
            <Chip
              key={cat}
              selected={filters.category === cat || (!filters.category && cat === 'all')}
              onPress={() => onFilterChange({ ...filters, category: cat })}
            >
              <ChipText
                selected={filters.category === cat || (!filters.category && cat === 'all')}
              >
                {getCategoryLabel(cat)}
              </ChipText>
            </Chip>
          ))}
        </XStack>
      </ScrollView>
    </XStack>
  );
}
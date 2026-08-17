// apps/mobile/src/components/expenses/ExpenseCard.tsx
// Single expense card component

import React from 'react';
import { Card, Text, XStack, YStack } from '@expense/ui';
import type { Expense } from '@expense/shared';
import { formatCurrency, CATEGORY_LABELS } from '@expense/shared';
import { MaterialCommunityIcons } from '@expo/vector-icons';

interface ExpenseCardProps {
  expense: Expense;
  onPress?: () => void;
  walletName?: string;
}

const CATEGORY_ICONS: Record<string, string> = {
  food: 'food',
  transport: 'bus',
  shopping: 'shopping',
  entertainment: 'movie-open',
  healthcare: 'medical-bag',
  education: 'school',
  bills: 'file-document-outline',
  savings: 'piggy-bank',
  other: 'dots-horizontal',
};

const CATEGORY_COLORS: Record<string, string> = {
  food: '#F97316',
  transport: '#3B82F6',
  shopping: '#EC4899',
  entertainment: '#A855F7',
  healthcare: '#EF4444',
  education: '#6366F1',
  bills: '#78716C',
  savings: '#0369A1',
  other: '#64748B',
};

export function ExpenseCard({ expense, onPress, walletName }: ExpenseCardProps) {
  const iconName = CATEGORY_ICONS[expense.category] ?? 'dots-horizontal';
  const categoryColor = CATEGORY_COLORS[expense.category] ?? '#64748B';
  const categoryLabel = CATEGORY_LABELS[expense.category];
  const isVoided = expense.status === 'voided';

  const formattedDate = new Date(expense.date).toLocaleDateString('vi-VN', {
    day: '2-digit',
    month: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
  });

  return (
    <Card pressable={!!onPress} elevated onPress={onPress}>
      <XStack justifyContent="space-between" alignItems="center" opacity={isVoided ? 0.5 : 1}>
        <XStack gap="$3" alignItems="center" flex={1}>
          <MaterialCommunityIcons name={iconName as any} size={24} color={categoryColor} />
          <YStack gap="$1" flex={1}>
            <Text
              fontSize="$md"
              fontWeight="500"
              numberOfLines={1}
              textDecorationLine={isVoided ? 'line-through' : 'none'}
            >
              {expense.description || categoryLabel}
            </Text>
            <XStack gap="$2" alignItems="center">
              <Text fontSize="$xs" color="$onSurfaceVariant">
                {categoryLabel}
              </Text>
              {walletName && (
                <Text fontSize="$xs" color="$onSurfaceVariant">
                  • {walletName}
                </Text>
              )}
            </XStack>
            <Text fontSize="$xs" color="$onSurfaceVariant">
              {formattedDate}
            </Text>
          </YStack>
        </XStack>
        <YStack alignItems="flex-end" gap="$1">
          <Text
            fontSize="$lg"
            fontWeight="600"
            color={isVoided ? '$onSurfaceVariant' : '$expense'}
            textDecorationLine={isVoided ? 'line-through' : 'none'}
          >
            {formatCurrency(expense.amount, expense.currency)}
          </Text>
          {isVoided && (
            <Text fontSize="$xs" color="$onSurfaceVariant">
              Đã hủy
            </Text>
          )}
        </YStack>
      </XStack>
    </Card>
  );
}

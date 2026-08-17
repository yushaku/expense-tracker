// apps/mobile/src/components/incomes/IncomeCard.tsx
// Single income card component with income color scheme

import React from 'react';
import { Card, Text, XStack, YStack } from '@expense/ui';
import { Income, formatCurrency } from '@expense/shared';
import { MaterialCommunityIcons } from '@expo/vector-icons';
import {
  INCOME_TYPE_LABELS,
  INCOME_TYPE_COLORS,
  INCOME_TYPE_ICONS,
} from '../../stores/incomeStore';

interface IncomeCardProps {
  income: Income;
  onPress?: () => void;
  walletName?: string;
}

export function IncomeCard({ income, onPress, walletName }: IncomeCardProps) {
  const iconName = INCOME_TYPE_ICONS[income.type] ?? 'dots-horizontal';
  const typeColor = INCOME_TYPE_COLORS[income.type] ?? '#64748B';
  const typeLabel = INCOME_TYPE_LABELS[income.type];
  const isVoided = income.status === 'voided';

  const formattedDate = new Date(income.date).toLocaleDateString('vi-VN', {
    day: '2-digit',
    month: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
  });

  return (
    <Card pressable={!!onPress} elevated onPress={onPress}>
      <XStack justifyContent="space-between" alignItems="center" opacity={isVoided ? 0.5 : 1}>
        <XStack gap="$3" alignItems="center" flex={1}>
          <MaterialCommunityIcons
            name={iconName as any}
            size={24}
            color={typeColor}
          />
          <YStack gap="$1" flex={1}>
            <Text
              fontSize="$md"
              fontWeight="500"
              numberOfLines={1}
              textDecorationLine={isVoided ? 'line-through' : 'none'}
            >
              {income.description || income.source || typeLabel}
            </Text>
            <XStack gap="$2" alignItems="center">
              <Text fontSize="$xs" color="$onSurfaceVariant">
                {typeLabel}
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
            color={isVoided ? '$onSurfaceVariant' : '$income'}
            textDecorationLine={isVoided ? 'line-through' : 'none'}
          >
            +{formatCurrency(income.amount, income.currency)}
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
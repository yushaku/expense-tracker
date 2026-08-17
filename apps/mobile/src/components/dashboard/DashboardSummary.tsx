// apps/mobile/src/components/dashboard/DashboardSummary.tsx
// Cash flow card + Savings rate card

import { Card, XStack, YStack, Text } from '@expense/ui';
import { formatCurrency } from '@expense/shared';

interface DashboardSummaryProps {
  cashFlow: number;
  savingsRate: number;
  currency?: string;
}

export function DashboardSummary({ cashFlow, savingsRate, currency = 'VND' }: DashboardSummaryProps) {
  const isPositive = cashFlow >= 0;
  const isSavingsPositive = savingsRate >= 0;

  return (
    <XStack gap="$3" flexWrap="wrap">
      {/* Cash Flow Card */}
      <Card flex={1} minWidth={150} elevated>
        <YStack gap="$2">
          <Text fontSize="$sm" color="$onSurfaceVariant">
            Dòng tiền
          </Text>
          <Text
            fontSize="$3xl"
            fontWeight="bold"
            color={isPositive ? '$income' : '$expense'}
          >
            {isPositive ? '+' : ''}{formatCurrency(cashFlow, currency)}
          </Text>
          <Text fontSize="$xs" color="$onSurfaceVariant">
            {isPositive ? 'Thặng dư' : 'Thâm hụt'}
          </Text>
        </YStack>
      </Card>

      {/* Savings Rate Card */}
      <Card flex={1} minWidth={150} elevated>
        <YStack gap="$2">
          <Text fontSize="$sm" color="$onSurfaceVariant">
            Tỷ lệ tiết kiệm
          </Text>
          <Text
            fontSize="$3xl"
            fontWeight="bold"
            color={isSavingsPositive ? '$savings' : '$expense'}
          >
            {savingsRate.toFixed(1)}%
          </Text>
          <Text fontSize="$xs" color="$onSurfaceVariant">
            {isSavingsPositive ? 'Đang tiết kiệm' : 'Chi tiêu vượt mức'}
          </Text>
        </YStack>
      </Card>
    </XStack>
  );
}
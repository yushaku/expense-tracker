// apps/mobile/src/components/dashboard/CategoryChart.tsx
// Bar chart for category breakdown

import { Card, XStack, YStack, Text } from '@expense/ui';
import { CategoryBreakdownItem } from '../../stores/dashboardStore';
import { formatCurrency } from '@expense/shared';

interface CategoryChartProps {
  categories: CategoryBreakdownItem[];
  currency?: string;
}

export function CategoryChart({ categories, currency = 'VND' }: CategoryChartProps) {
  if (categories.length === 0) {
    return (
      <Card elevated>
        <YStack gap="$2" alignItems="center" paddingVertical="$4">
          <Text fontSize="$sm" color="$onSurfaceVariant">
            Chưa có chi tiêu trong tháng này
          </Text>
        </YStack>
      </Card>
    );
  }

  return (
    <Card elevated>
      <YStack gap="$3">
        <Text fontSize="$lg" fontWeight="600">
          Chi tiêu theo danh mục
        </Text>
        <YStack gap="$2">
          {categories.map((item) => (
            <CategoryBar
              key={item.category}
              label={item.label}
              amount={item.amount}
              percentage={item.percentage}
              color={item.color}
              currency={currency}
            />
          ))}
        </YStack>
      </YStack>
    </Card>
  );
}

interface CategoryBarProps {
  label: string;
  amount: number;
  percentage: number;
  color: string;
  currency: string;
}

function CategoryBar({ label, amount, percentage, color, currency }: CategoryBarProps) {
  return (
    <YStack gap="$1">
      <XStack justifyContent="space-between" alignItems="center">
        <XStack gap="$2" alignItems="center" flex={1}>
          <XStack
            width={12}
            height={12}
            borderRadius={2}
            backgroundColor={color}
          />
          <Text fontSize="$sm" flex={1} numberOfLines={1}>
            {label}
          </Text>
        </XStack>
        <Text fontSize="$sm" fontWeight="500" marginLeft="$2">
          {percentage.toFixed(1)}%
        </Text>
      </XStack>
      <XStack height={8} backgroundColor="$surfaceVariant" borderRadius={4} overflow="hidden">
        <XStack
          width={`${Math.min(percentage, 100)}%`}
          backgroundColor={color}
          borderRadius={4}
        />
      </XStack>
      <Text fontSize="$xs" color="$onSurfaceVariant">
        {formatCurrency(amount, currency)}
      </Text>
    </YStack>
  );
}
// apps/mobile/app/index.tsx
// Dashboard home screen — Cash flow, Category breakdown, Savings rate, Wallet balances

import { useEffect } from 'react';
import { YStack, ScrollView, Text, Spinner } from '@expense/ui';
import { useDashboardStore } from '../src/stores/dashboardStore';
import { DashboardSummary } from '../src/components/dashboard/DashboardSummary';
import { CategoryChart } from '../src/components/dashboard/CategoryChart';
import { WalletSummary } from '../src/components/dashboard/WalletSummary';

export default function HomeScreen() {
  const {
    cashFlow,
    savingsRate,
    categoryBreakdown,
    walletBalances,
    loading,
    error,
    loadDashboardData,
  } = useDashboardStore();

  useEffect(() => {
    loadDashboardData();
  }, [loadDashboardData]);

  if (loading && categoryBreakdown.length === 0 && walletBalances.length === 0) {
    return (
      <YStack flex={1} justifyContent="center" alignItems="center">
        <Spinner size="large" color="$primary" />
        <Text fontSize="$sm" color="$onSurfaceVariant" marginTop="$3">
          Đang tải dữ liệu...
        </Text>
      </YStack>
    );
  }

  return (
    <ScrollView flex={1} contentContainerStyle={{ padding: 16, paddingBottom: 80 }}>
      <YStack gap="$4">
        {/* Header */}
        <YStack gap="$1">
          <Text fontSize="$xl" fontWeight="bold">
            Tổng quan
          </Text>
          <Text fontSize="$sm" color="$onSurfaceVariant">
            Tháng {new Date().toLocaleDateString('vi-VN', { month: 'long', year: 'numeric' })}
          </Text>
        </YStack>

        {/* Error state */}
        {error && (
          <YStack
            backgroundColor="$error"
            borderRadius="$3"
            padding="$3"
            gap="$1"
          >
            <Text fontSize="$sm" color="white">
              {error}
            </Text>
          </YStack>
        )}

        {/* Cash Flow + Savings Rate */}
        <DashboardSummary
          cashFlow={cashFlow}
          savingsRate={savingsRate}
        />

        {/* Category Breakdown */}
        <CategoryChart categories={categoryBreakdown} />

        {/* Wallet Balances */}
        <WalletSummary wallets={walletBalances} />
      </YStack>
    </ScrollView>
  );
}
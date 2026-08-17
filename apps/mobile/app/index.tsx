// apps/mobile/app/index.tsx
// Dashboard home screen — Hero balance card, Income/Expense summary, Recent transactions

import { useEffect } from 'react';
import { YStack, ScrollView, Text, Spinner, Card, XStack, useTheme } from 'tamagui';
import { useDashboardStore } from '../src/stores/dashboardStore';
import { formatMoney } from '@expense/domain';
import { MaterialCommunityIcons } from '@expo/vector-icons';

export default function HomeScreen() {
  const {
    cashFlowMinor,
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

  // Calculate total balance from all wallets
  const totalBalance = walletBalances.reduce(
    (sum, w) => sum + w.balanceMinor,
    0n
  );

  // Calculate total income & expense from cashFlow
  // cashFlow = income - expense (positive = surplus)
  // For demo: derive income/expense from categories
  const totalExpense = categoryBreakdown.reduce(
    (sum, c) => sum + c.amountMinor,
    0n
  );
  const totalIncome = totalExpense + cashFlowMinor;

  return (
    <ScrollView
      flex={1}
      backgroundColor="$background"
      contentContainerStyle={{ paddingBottom: 100 }}
    >
      <YStack gap="$4" padding="$4">
        {/* Header */}
        <YStack gap="$1" marginTop="$2">
          <Text fontSize="$xl" fontWeight="bold" color="$onSurface">
            Tổng quan
          </Text>
          <Text fontSize="$sm" color="$onSurfaceMuted">
            Tháng {new Date().toLocaleDateString('vi-VN', { month: 'long', year: 'numeric' })}
          </Text>
        </YStack>

        {/* Error state */}
        {error && (
          <Card backgroundColor="$error" borderRadius="$3" padding="$3">
            <Text fontSize="$sm" color="white">
              {error}
            </Text>
          </Card>
        )}

        {/* Hero Balance Card */}
        <Card
          elevated
          backgroundColor="$primary"
          borderRadius="$6"
          padding="$5"
        >
          <YStack gap="$2">
            <Text fontSize="$sm" color="$onPrimary" opacity={0.8}>
              Tổng tài sản
            </Text>
            <Text fontSize="$3xl" fontWeight="bold" color="$onPrimary">
              {formatMoney({ minorUnits: totalBalance, currency: 'VND' })}
            </Text>
            <Text fontSize="$xs" color="$onPrimary" opacity={0.7}>
              {walletBalances.length} ví
            </Text>
          </YStack>
        </Card>

        {/* Income/Expense Summary Cards */}
        <XStack gap="$3">
          {/* Income Card */}
          <Card flex={1} elevated borderRadius="$4" padding="$4">
            <YStack gap="$2">
              <XStack alignItems="center" gap="$2">
                <MaterialCommunityIcons
                  name="arrow-down"
                  size={16}
                  color="#a6d189"
                />
                <Text fontSize="$xs" color="$onSurfaceMuted">
                  Thu nhập
                </Text>
              </XStack>
              <Text fontSize="$lg" fontWeight="600" color="$income">
                {formatMoney({ minorUnits: totalIncome > 0n ? totalIncome : 0n, currency: 'VND' })}
              </Text>
            </YStack>
          </Card>

          {/* Expense Card */}
          <Card flex={1} elevated borderRadius="$4" padding="$4">
            <YStack gap="$2">
              <XStack alignItems="center" gap="$2">
                <MaterialCommunityIcons
                  name="arrow-up"
                  size={16}
                  color="#e78284"
                />
                <Text fontSize="$xs" color="$onSurfaceMuted">
                  Chi tiêu
                </Text>
              </XStack>
              <Text fontSize="$lg" fontWeight="600" color="$expense">
                {formatMoney({ minorUnits: totalExpense, currency: 'VND' })}
              </Text>
            </YStack>
          </Card>
        </XStack>

        {/* Savings Rate Mini Card */}
        <Card elevated borderRadius="$4" padding="$4">
          <XStack justifyContent="space-between" alignItems="center">
            <YStack gap="$1">
              <Text fontSize="$sm" color="$onSurfaceMuted">
                Tỷ lệ tiết kiệm
              </Text>
              <Text fontSize="$2xl" fontWeight="bold" color={savingsRate >= 0 ? '$savings' : '$expense'}>
                {savingsRate.toFixed(1)}%
              </Text>
            </YStack>
            <MaterialCommunityIcons
              name={savingsRate >= 0 ? 'trending-up' : 'trending-down'}
              size={32}
              color={savingsRate >= 0 ? '#a6d189' : '#e78284'}
            />
          </XStack>
        </Card>

        {/* Recent Transactions */}
        <YStack gap="$2">
          <Text fontSize="$md" fontWeight="600" color="$onSurface">
            Giao dịch gần đây
          </Text>
          {categoryBreakdown.length === 0 ? (
            <Card borderRadius="$3" padding="$4">
              <Text fontSize="$sm" color="$onSurfaceMuted" textAlign="center">
                Chưa có giao dịch nào
              </Text>
            </Card>
          ) : (
            categoryBreakdown.slice(0, 5).map((item) => (
              <Card key={item.categoryId} borderRadius="$3" padding="$3">
                <XStack justifyContent="space-between" alignItems="center">
                  <XStack alignItems="center" gap="$3" flex={1}>
                    <XStack
                      width={36}
                      height={36}
                      borderRadius="$2"
                      backgroundColor="$surfaceVariant"
                      alignItems="center"
                      justifyContent="center"
                    >
                      <MaterialCommunityIcons
                        name="tag"
                        size={18}
                        color={item.color}
                      />
                    </XStack>
                    <YStack gap="$0.5">
                      <Text fontSize="$sm" fontWeight="500" color="$onSurface">
                        {item.label}
                      </Text>
                      <Text fontSize="$xs" color="$onSurfaceMuted">
                        {item.percentage.toFixed(1)}%
                      </Text>
                    </YStack>
                  </XStack>
                  <Text fontSize="$sm" fontWeight="600" color="$expense">
                    {formatMoney({ minorUnits: item.amountMinor, currency: 'VND' })}
                  </Text>
                </XStack>
              </Card>
            ))
          )}
        </YStack>
      </YStack>
    </ScrollView>
  );
}
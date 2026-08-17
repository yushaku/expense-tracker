// apps/mobile/app/investments/index.tsx
// Investments list — portfolio overview

import React from 'react';
import { ScrollView, Text, XStack, YStack, Card, FAB } from '@expense/ui';
import { MaterialCommunityIcons } from '@expo/vector-icons';
import { useRouter } from 'expo-router';

const INVESTMENT_TYPES = [
  { type: 'gold', label: 'Vàng', icon: 'gold', color: '#e5c890' },
  { type: 'crypto', label: 'Crypto', icon: 'bitcoin', color: '#ef9f76' },
  { type: 'stock', label: 'Cổ phiếu', icon: 'chart-line', color: '#ca9ee6' },
  { type: 'real_estate', label: 'BĐS', icon: 'home-city', color: '#8caaee' },
  { type: 'fund', label: 'Quỹ', icon: 'chart-pie', color: '#a6d189' },
  { type: 'bond', label: 'Trái phiếu', icon: 'file-document', color: '#81c8be' },
];

export default function InvestmentsScreen() {
  const router = useRouter();

  return (
    <ScrollView flex={1} backgroundColor="$background">
      <YStack gap="$4" padding="$4">
        <Text fontSize="$xl" fontWeight="bold">
          Đầu tư
        </Text>

        {/* Net Worth Card */}
        <Card elevated padding="$4">
          <YStack gap="$2" alignItems="center">
            <Text fontSize="$sm" color="$muted">
              Tổng tài sản đầu tư
            </Text>
            <Text fontSize="$2xl" fontWeight="bold" color="$primary">
              0 ₫
            </Text>
            <Text fontSize="$xs" color="$muted">
              Chưa có khoản đầu tư nào
            </Text>
          </YStack>
        </Card>

        {/* Asset Allocation */}
        <Card elevated padding="$4">
          <Text fontSize="$md" fontWeight="600" marginBottom="$3">
            Phân bổ tài sản
          </Text>
          <YStack gap="$2" alignItems="center" paddingVertical="$4">
            <Text color="$muted" textAlign="center">
              Thêm khoản đầu tư đầu tiên để xem phân bổ
            </Text>
          </YStack>
        </Card>

        {/* Investment List */}
        <Text fontSize="$md" fontWeight="600">
          Danh sách đầu tư
        </Text>
        <YStack gap="$2" alignItems="center" paddingVertical="$8">
          <MaterialCommunityIcons
            name="briefcase-outline"
            size={48}
            color="#737994"
          />
          <Text color="$muted" textAlign="center">
            Chưa có khoản đầu tư nào
          </Text>
          <Text fontSize="$xs" color="$muted" textAlign="center">
            Nhấn + để thêm khoản đầu tư đầu tiên
          </Text>
        </YStack>
      </YStack>

      <FAB
        icon={<MaterialCommunityIcons name="plus" size={24} color="white" />}
        onPress={() => router.push('/investments/new' as any)}
        ariaLabel="Thêm đầu tư"
      />
    </ScrollView>
  );
}

// apps/mobile/app/wallets/index.tsx
// Wallet list screen — iOS-style cards with balance display

import { useEffect } from 'react';
import { YStack, Text, ScrollView, Spinner } from 'tamagui';
import { useWalletStore } from '../../src/stores/walletStore';
import { WalletList } from '../../src/components/wallets/WalletList';
import { FAB } from '@expense/ui';
import { useRouter } from 'expo-router';
import { MaterialCommunityIcons } from '@expo/vector-icons';
import { formatMoney } from '@expense/domain';
import { XStack, Card } from 'tamagui';

export default function WalletsScreen() {
  const router = useRouter();
  const { wallets, loading, error, loadWallets } = useWalletStore();

  useEffect(() => {
    loadWallets();
  }, []);

  // Calculate total balance
  const totalBalance = wallets.reduce((sum, w) => sum + (w.balanceMinor ?? 0n), 0n);

  return (
    <YStack flex={1} backgroundColor="$background">
      <ScrollView contentContainerStyle={{ paddingBottom: 100 }}>
        <YStack gap="$4" padding="$4">
          {/* Header */}
          <YStack gap="$1" marginTop="$2">
            <Text fontSize="$xl" fontWeight="bold" color="$onSurface">
              Ví của tôi
            </Text>
            <Text fontSize="$sm" color="$onSurfaceMuted">
              Quản lý tài chính cá nhân
            </Text>
          </YStack>

          {/* Total Balance Card */}
          <Card elevated backgroundColor="$primary" borderRadius="$6" padding="$5">
            <YStack gap="$1">
              <Text fontSize="$xs" color="$onPrimary" opacity={0.8}>
                Tổng số dư
              </Text>
              <Text fontSize="$2xl" fontWeight="bold" color="$onPrimary">
                {formatMoney({ minorUnits: totalBalance, currency: 'VND' })}
              </Text>
            </YStack>
          </Card>

          {/* Error state */}
          {error && (
            <Card backgroundColor="$error" borderRadius="$3" padding="$3">
              <Text fontSize="$sm" color="white">
                {error}
              </Text>
            </Card>
          )}

          {/* Wallet List */}
          {loading ? (
            <YStack padding="$4" alignItems="center">
              <Spinner size="small" color="$primary" />
              <Text fontSize="$sm" color="$onSurfaceMuted" marginTop="$2">
                Đang tải...
              </Text>
            </YStack>
          ) : wallets.length === 0 ? (
            <Card borderRadius="$4" padding="$6">
              <YStack alignItems="center" gap="$2">
                <MaterialCommunityIcons name="wallet-outline" size={48} color="#737994" />
                <Text fontSize="$sm" color="$onSurfaceMuted">
                  Chưa có ví nào
                </Text>
                <Text fontSize="$xs" color="$onSurfaceMuted" textAlign="center">
                  Nhấn nút + để tạo ví đầu tiên
                </Text>
              </YStack>
            </Card>
          ) : (
            <WalletList
              wallets={wallets}
              onWalletPress={(wallet: any) => router.push(`/wallets/${wallet.id}` as any)}
            />
          )}
        </YStack>
      </ScrollView>

      {/* FAB */}
      <FAB
        icon={<MaterialCommunityIcons name="plus" size={24} color="white" />}
        onPress={() => router.push('/wallets/new' as any)}
        ariaLabel="Tạo ví mới"
      />
    </YStack>
  );
}

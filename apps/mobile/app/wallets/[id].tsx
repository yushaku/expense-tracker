// apps/mobile/app/wallets/[id].tsx
// Wallet detail screen
import React, { useEffect, useState } from 'react';
import { YStack, Text, XStack } from '@expense/ui';
import { useWalletStore, WalletWithBalance } from '@/src/stores/walletStore';
import { useLocalSearchParams, useRouter } from 'expo-router';
import { formatMoney } from '@expense/domain';
import { MaterialCommunityIcons } from '@expo/vector-icons';

const WALLET_ICONS: Record<string, string> = {
  cash: 'cash',
  bank: 'bank',
  ewallet: 'cellphone',
  credit_card: 'credit-card',
};

const WALLET_LABELS: Record<string, string> = {
  cash: 'Tiền mặt',
  bank: 'Tài khoản',
  ewallet: 'Ví điện tử',
  credit_card: 'Thẻ tín dụng',
};

export default function WalletDetailScreen() {
  const router = useRouter();
  const { id } = useLocalSearchParams<{ id: string }>();
  const { getWalletById, loadWallets } = useWalletStore();
  const [wallet, setWallet] = useState<WalletWithBalance | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    loadWallets().then(() => {
      if (id) {
        setWallet(getWalletById(id));
      }
      setLoading(false);
    });
  }, [id]);

  if (loading) {
    return (
      <YStack flex={1} padding="$4" gap="$4" justifyContent="center" alignItems="center">
        <Text color="$onSurfaceVariant">Đang tải...</Text>
      </YStack>
    );
  }

  if (!wallet) {
    return (
      <YStack flex={1} padding="$4" gap="$4">
        <Text color="$onSurfaceVariant">Không tìm thấy ví</Text>
      </YStack>
    );
  }

  const iconName = WALLET_ICONS[wallet.type] ?? 'wallet';
  const label = WALLET_LABELS[wallet.type] ?? wallet.type;
  const isCreditCard = wallet.type === 'credit_card';
  const currency = wallet.currency ?? 'VND';

  const balanceMinor = wallet.balanceMinor;
  const creditLimitMinor = wallet.creditLimitMinor;

  return (
    <YStack flex={1} backgroundColor="$background">
      <YStack flex={1} padding="$4" gap="$4">
        <XStack justifyContent="space-between" alignItems="center">
          <Text fontSize="$2xl" fontWeight="bold">
            {wallet.name}
          </Text>
        </XStack>

        <YStack backgroundColor="$surface" borderRadius="$3" padding="$4" gap="$3">
          <XStack gap="$3" alignItems="center">
            <MaterialCommunityIcons name={iconName as any} size={32} color="#0F766E" />
            <YStack flex={1}>
              <Text fontSize="$lg" fontWeight="600">
                {wallet.name}
              </Text>
              <Text fontSize={14} color="$onSurfaceVariant">
                {label}
              </Text>
            </YStack>
          </XStack>

          <YStack gap="$1">
            <Text fontSize={14} color="$onSurfaceVariant">
              {isCreditCard ? 'Dư nợ hiện tại' : 'Số dư'}
            </Text>
            <Text
              fontSize="$3xl"
              fontWeight="bold"
              color={isCreditCard ? '$expense' : balanceMinor >= 0n ? '$income' : '$expense'}
            >
              {isCreditCard
                ? formatMoney({ minorUnits: balanceMinor < 0n ? -balanceMinor : balanceMinor, currency })
                : formatMoney({ minorUnits: balanceMinor, currency })}
            </Text>
          </YStack>

          {isCreditCard && creditLimitMinor > 0n && (
            <YStack gap="$2">
              <XStack justifyContent="space-between">
                <Text fontSize={14} color="$onSurfaceVariant">
                  Hạn mức
                </Text>
                <Text fontSize={14}>{formatMoney({ minorUnits: creditLimitMinor, currency })}</Text>
              </XStack>
              <XStack justifyContent="space-between">
                <Text fontSize={14} color="$onSurfaceVariant">
                  Đã sử dụng
                </Text>
                <Text fontSize={14} color="$expense">
                  {formatMoney({ minorUnits: balanceMinor < 0n ? -balanceMinor : balanceMinor, currency })}
                </Text>
              </XStack>
              <XStack justifyContent="space-between">
                <Text fontSize={14} color="$onSurfaceVariant">
                  Còn lại
                </Text>
                <Text fontSize={14} color="$income">
                  {formatMoney({ minorUnits: creditLimitMinor - (balanceMinor < 0n ? -balanceMinor : balanceMinor), currency })}
                </Text>
              </XStack>
            </YStack>
          )}
        </YStack>

        <Text fontSize="$lg" fontWeight="600">
          Giao dịch gần đây
        </Text>
        <Text color="$onSurfaceVariant">Chưa có giao dịch nào.</Text>
      </YStack>
    </YStack>
  );
}
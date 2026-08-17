// apps/mobile/src/components/wallets/WalletCard.tsx
// Single wallet card component (v3: @expense/domain)

import React from 'react';
import { Card, Text, XStack, YStack } from '@expense/ui';
import { formatMoney } from '@expense/domain';
import { MaterialCommunityIcons } from '@expo/vector-icons';

interface WalletCardProps {
  wallet: {
    id: string;
    name: string;
    type: 'cash' | 'bank' | 'ewallet' | 'credit_card';
    currency: string;
    creditLimitMinor: bigint;
    balanceMinor: bigint;
  };
  onPress?: () => void;
}

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

export function WalletCard({ wallet, onPress }: WalletCardProps) {
  const iconName = WALLET_ICONS[wallet.type] ?? 'wallet';
  const label = WALLET_LABELS[wallet.type] ?? wallet.type;
  const isCreditCard = wallet.type === 'credit_card';

  return (
    <Card pressable={!!onPress} elevated onPress={onPress}>
      <XStack justifyContent="space-between" alignItems="center">
        <XStack gap="$3" alignItems="center" flex={1}>
          <MaterialCommunityIcons name={iconName as any} size={24} color="#0F766E" />
          <YStack gap="$1" flex={1}>
            <Text fontSize="$md" fontWeight="600" numberOfLines={1}>
              {wallet.name}
            </Text>
            <Text fontSize="$xs" color="$onSurfaceVariant">
              {label}
              {isCreditCard && wallet.creditLimitMinor > 0n
                ? ` • Hạn mức: ${formatMoney({ minorUnits: wallet.creditLimitMinor, currency: wallet.currency })}`
                : ''}
            </Text>
          </YStack>
        </XStack>
        <YStack alignItems="flex-end" gap="$1">
          <Text
            fontSize="$lg"
            fontWeight="600"
            color={isCreditCard ? '$expense' : wallet.balanceMinor >= 0n ? '$income' : '$expense'}
          >
            {formatMoney({
              minorUnits: wallet.balanceMinor >= 0n ? wallet.balanceMinor : -wallet.balanceMinor,
              currency: wallet.currency,
            })}
          </Text>
          {isCreditCard && (
            <Text fontSize="$xs" color="$onSurfaceVariant">
              Nợ
            </Text>
          )}
        </YStack>
      </XStack>
    </Card>
  );
}

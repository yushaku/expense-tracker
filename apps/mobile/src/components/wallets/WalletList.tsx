// apps/mobile/src/components/wallets/WalletList.tsx
// List of wallets with balance

import React from 'react';
import { YStack, Text } from '@expense/ui';
import { WalletWithBalance } from '@expense/shared';
import { WalletCard } from './WalletCard';

interface WalletListProps {
  wallets: WalletWithBalance[];
  onWalletPress?: (wallet: WalletWithBalance) => void;
  loading?: boolean;
}

export function WalletList({ wallets, onWalletPress, loading }: WalletListProps) {
  if (loading) {
    return (
      <YStack padding="$4">
        <Text color="$onSurfaceVariant">Đang tải...</Text>
      </YStack>
    );
  }

  if (wallets.length === 0) {
    return (
      <YStack padding="$4" gap="$2">
        <Text color="$onSurfaceVariant" textAlign="center">
          Chưa có ví nào.
        </Text>
        <Text color="$onSurfaceVariant" textAlign="center" fontSize={14}>
          Nhấn + để tạo ví đầu tiên.
        </Text>
      </YStack>
    );
  }

  return (
    <YStack gap="$2">
      {wallets.map((wallet) => (
        <WalletCard
          key={wallet.id}
          wallet={wallet}
          onPress={onWalletPress ? () => onWalletPress(wallet) : undefined}
        />
      ))}
    </YStack>
  );
}
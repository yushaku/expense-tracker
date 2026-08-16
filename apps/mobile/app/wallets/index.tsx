// apps/mobile/app/wallets/index.tsx
// Wallet list screen

import React, { useEffect, useState } from 'react';
import { YStack, Text } from '@expense/ui';
import { useWalletStore } from '../../src/stores/walletStore';
import { WalletList } from '../../src/components/wallets/WalletList';
import { FAB } from '@expense/ui';
import { useRouter } from 'expo-router';
import { MaterialCommunityIcons } from '@expo/vector-icons';

export default function WalletsScreen() {
  const router = useRouter();
  const { wallets, loading, error, loadWallets } = useWalletStore();

  useEffect(() => {
    loadWallets();
  }, []);

  const handleWalletPress = (wallet: any) => {
    router.push(`/wallets/${wallet.id}` as any);
  };

  return (
    <YStack flex={1} backgroundColor="$background">
      <YStack flex={1} padding="$4" gap="$4">
        <Text fontSize="$2xl" fontWeight="bold">
          Ví của tôi
        </Text>

        {error && (
          <Text color="$error" fontSize={14}>
            {error}
          </Text>
        )}

        <WalletList
          wallets={wallets}
          onWalletPress={handleWalletPress}
          loading={loading}
        />
      </YStack>

      <FAB
        icon={<MaterialCommunityIcons name="plus" size={24} color="white" />}
        onPress={() => router.push('/wallets/new' as any)}
        ariaLabel="Tạo ví mới"
      />
    </YStack>
  );
}
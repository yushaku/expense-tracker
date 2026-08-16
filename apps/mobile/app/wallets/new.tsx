// apps/mobile/app/wallets/new.tsx
// Create wallet screen

import React from 'react';
import { YStack } from '@expense/ui';
import { useWalletStore } from '../../src/stores/walletStore';
import { WalletForm } from '../../src/components/wallets/WalletForm';
import { useRouter } from 'expo-router';

export default function NewWalletScreen() {
  const router = useRouter();
  const { createWallet } = useWalletStore();

  const handleSubmit = async (data: any) => {
    await createWallet(data);
    router.back();
  };

  return (
    <YStack flex={1} backgroundColor="$background">
      <WalletForm
        onSubmit={handleSubmit}
        onCancel={() => router.back()}
      />
    </YStack>
  );
}
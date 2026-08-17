// apps/mobile/app/wallets/transfer.tsx
// Transfer screen

import React from 'react';
import { YStack } from '@expense/ui';
import { useWalletStore } from '../../src/stores/walletStore';
import { TransferForm } from '../../src/components/wallets/TransferForm';
import { useRouter } from 'expo-router';

export default function TransferScreen() {
  const router = useRouter();
  const { wallets, transfer } = useWalletStore();

  const handleSubmit = async (data: any) => {
    await transfer(data);
    router.back();
  };

  return (
    <YStack flex={1} backgroundColor="$background">
      <TransferForm wallets={wallets} onSubmit={handleSubmit} onCancel={() => router.back()} />
    </YStack>
  );
}

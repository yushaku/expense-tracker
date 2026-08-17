// apps/mobile/app/incomes/new.tsx
// Create income screen

import React from 'react';
import { YStack } from '@expense/ui';
import { useIncomeStore } from '../../src/stores/incomeStore';
import { useWalletStore } from '../../src/stores/walletStore';
import { IncomeForm } from '../../src/components/incomes/IncomeForm';
import { useRouter } from 'expo-router';
import { useEffect } from 'react';

export default function NewIncomeScreen() {
  const router = useRouter();
  const { addIncome, loading } = useIncomeStore();
  const { wallets, loadWallets } = useWalletStore();

  useEffect(() => {
    loadWallets();
  }, []);

  const handleSubmit = async (data: any) => {
    await addIncome(data);
    router.back();
  };

  return (
    <YStack flex={1} backgroundColor="$background">
      <IncomeForm
        wallets={wallets}
        onSubmit={handleSubmit}
        onCancel={() => router.back()}
        loading={loading}
      />
    </YStack>
  );
}
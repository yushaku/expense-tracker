// apps/mobile/app/expenses/new.tsx
// Create expense screen

import React from 'react';
import { YStack } from '@expense/ui';
import { useExpenseStore } from '@/src/stores/expenseStore';
import { useWalletStore } from '@/src/stores/walletStore';
import { ExpenseForm } from '@/src/components/expenses/ExpenseForm';
import { useRouter } from 'expo-router';
import { useEffect } from 'react';

export default function NewExpenseScreen() {
  const router = useRouter();
  const { addExpense, loading } = useExpenseStore();
  const { wallets, loadWallets } = useWalletStore();

  useEffect(() => {
    loadWallets();
  }, []);

  const handleSubmit = async (data: any) => {
    await addExpense(data);
    router.back();
  };

  return (
    <YStack flex={1} backgroundColor="$background">
      <ExpenseForm
        wallets={wallets}
        onSubmit={handleSubmit}
        onCancel={() => router.back()}
        loading={loading}
      />
    </YStack>
  );
}

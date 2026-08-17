// apps/mobile/app/incomes/[id]/edit.tsx
// Edit income screen

import React, { useEffect, useState } from 'react';
import { YStack, Text } from '@expense/ui';
import { useIncomeStore } from '../../../src/stores/incomeStore';
import { useWalletStore } from '../../../src/stores/walletStore';
import { IncomeForm } from '../../../src/components/incomes/IncomeForm';
import { useRouter, useLocalSearchParams } from 'expo-router';
import type { Income } from '@expense/shared';
import { Wallet } from '@expense/shared';

export default function EditIncomeScreen() {
  const router = useRouter();
  const { id } = useLocalSearchParams<{ id: string }>();
  const { getIncomeById, updateIncome, loadIncomes, loading } = useIncomeStore();
  const { wallets, loadWallets } = useWalletStore();
  const [income, setIncome] = useState<Income | null>(null);
  const [notFound, setNotFound] = useState(false);

  useEffect(() => {
    loadIncomes().then(() => {
      if (id) {
        const found = getIncomeById(id);
        if (found) {
          setIncome(found);
        } else {
          setNotFound(true);
        }
      }
    });
    loadWallets();
  }, [id]);

  const handleSubmit = async (data: any) => {
    await updateIncome({
      id: income!.id,
      ...(data.amount !== undefined ? { amount: data.amount } : {}),
      ...(data.type ? { type: data.type } : {}),
      ...(data.source !== undefined ? { source: data.source } : {}),
      ...(data.description !== undefined ? { description: data.description } : {}),
    });
    router.back();
  };

  if (notFound) {
    return (
      <YStack flex={1} padding="$4" gap="$4">
        <Text color="$onSurfaceVariant">Không tìm thấy thu nhập</Text>
      </YStack>
    );
  }

  if (!income) {
    return (
      <YStack flex={1} padding="$4" gap="$4">
        <Text color="$onSurfaceVariant">Đang tải...</Text>
      </YStack>
    );
  }

  // Prevent editing voided incomes
  if (income.status === 'voided') {
    return (
      <YStack flex={1} padding="$4" gap="$4">
        <Text color="$error">Không thể sửa thu nhập đã hủy</Text>
      </YStack>
    );
  }

  return (
    <YStack flex={1} backgroundColor="$background">
      <IncomeForm
        initialData={income}
        wallets={wallets}
        onSubmit={handleSubmit}
        onCancel={() => router.back()}
        loading={loading}
      />
    </YStack>
  );
}

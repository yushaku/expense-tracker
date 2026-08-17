// apps/mobile/app/expenses/[id]/edit.tsx
// Edit expense screen

import React, { useEffect, useState } from 'react';
import { YStack, Text } from '@expense/ui';
import { useExpenseStore } from '@/src/stores/expenseStore';
import { useWalletStore } from '@/src/stores/walletStore';
import { ExpenseForm } from '@/src/components/expenses/ExpenseForm';
import { useRouter, useLocalSearchParams } from 'expo-router';
import type { Expense } from '@expense/shared';
import { Wallet } from '@expense/shared';

export default function EditExpenseScreen() {
  const router = useRouter();
  const { id } = useLocalSearchParams<{ id: string }>();
  const { getExpenseById, updateExpense, loadExpenses, loading } = useExpenseStore();
  const { wallets, loadWallets } = useWalletStore();
  const [expense, setExpense] = useState<Expense | null>(null);
  const [notFound, setNotFound] = useState(false);

  useEffect(() => {
    loadExpenses().then(() => {
      if (id) {
        const found = getExpenseById(id);
        if (found) {
          setExpense(found);
        } else {
          setNotFound(true);
        }
      }
    });
    loadWallets();
  }, [id]);

  const handleSubmit = async (data: any) => {
    await updateExpense({
      id: expense!.id,
      ...(data.amount !== undefined ? { amount: data.amount } : {}),
      ...(data.category ? { category: data.category } : {}),
      ...(data.description !== undefined ? { description: data.description } : {}),
    });
    router.back();
  };

  if (notFound) {
    return (
      <YStack flex={1} padding="$4" gap="$4">
        <Text color="$onSurfaceVariant">Không tìm thấy chi tiêu</Text>
      </YStack>
    );
  }

  if (!expense) {
    return (
      <YStack flex={1} padding="$4" gap="$4">
        <Text color="$onSurfaceVariant">Đang tải...</Text>
      </YStack>
    );
  }

  // Prevent editing voided expenses
  if (expense.status === 'voided') {
    return (
      <YStack flex={1} padding="$4" gap="$4">
        <Text color="$error">Không thể sửa chi tiêu đã hủy</Text>
      </YStack>
    );
  }

  return (
    <YStack flex={1} backgroundColor="$background">
      <ExpenseForm
        initialData={expense}
        wallets={wallets}
        onSubmit={handleSubmit}
        onCancel={() => router.back()}
        loading={loading}
      />
    </YStack>
  );
}

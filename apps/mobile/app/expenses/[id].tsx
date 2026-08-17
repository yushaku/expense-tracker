// apps/mobile/app/expenses/[id].tsx
// Expense detail screen

import React, { useEffect, useState } from 'react';
import { YStack, Text, XStack, Card, Button, Dialog } from '@expense/ui';
import { useExpenseStore } from '../../src/stores/expenseStore';
import { useWalletStore } from '../../src/stores/walletStore';
import { useLocalSearchParams, useRouter } from 'expo-router';
import type { Expense } from '@expense/shared';
import { formatCurrency, CATEGORY_LABELS } from '@expense/shared';
import { MaterialCommunityIcons } from '@expo/vector-icons';

const CATEGORY_ICONS: Record<string, string> = {
  food: 'food',
  transport: 'bus',
  shopping: 'shopping',
  entertainment: 'movie-open',
  healthcare: 'medical-bag',
  education: 'school',
  bills: 'file-document-outline',
  savings: 'piggy-bank',
  other: 'dots-horizontal',
};

const CATEGORY_COLORS: Record<string, string> = {
  food: '#F97316',
  transport: '#3B82F6',
  shopping: '#EC4899',
  entertainment: '#A855F7',
  healthcare: '#EF4444',
  education: '#6366F1',
  bills: '#78716C',
  savings: '#0369A1',
  other: '#64748B',
};

export default function ExpenseDetailScreen() {
  const router = useRouter();
  const { id } = useLocalSearchParams<{ id: string }>();
  const { getExpenseById, voidExpense, loadExpenses } = useExpenseStore();
  const { wallets, loadWallets } = useWalletStore();
  const [expense, setExpense] = useState<Expense | null>(null);
  const [showVoidDialog, setShowVoidDialog] = useState(false);
  const [voidLoading, setVoidLoading] = useState(false);

  useEffect(() => {
    loadExpenses().then(() => {
      if (id) {
        setExpense(getExpenseById(id));
      }
    });
    loadWallets();
  }, [id]);

  const wallet = wallets.find((w) => w.id === expense?.walletId);

  if (!expense) {
    return (
      <YStack flex={1} padding="$4" gap="$4">
        <Text color="$onSurfaceVariant">Không tìm thấy chi tiêu</Text>
      </YStack>
    );
  }

  const iconName = CATEGORY_ICONS[expense.category] ?? 'dots-horizontal';
  const categoryColor = CATEGORY_COLORS[expense.category] ?? '#64748B';
  const categoryLabel = CATEGORY_LABELS[expense.category];
  const isVoided = expense.status === 'voided';

  const formattedDate = new Date(expense.date).toLocaleDateString('vi-VN', {
    day: '2-digit',
    month: '2-digit',
    year: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
  });

  const handleVoid = async () => {
    setVoidLoading(true);
    try {
      await voidExpense(expense.id);
      setShowVoidDialog(false);
      setExpense(getExpenseById(expense.id));
    } catch (err: any) {
      // Error handled by store
    } finally {
      setVoidLoading(false);
    }
  };

  return (
    <YStack flex={1} backgroundColor="$background">
      <YStack flex={1} padding="$4" gap="$4">
        {/* Header */}
        <XStack justifyContent="space-between" alignItems="center">
          <Text fontSize="$2xl" fontWeight="bold">
            Chi tiết chi tiêu
          </Text>
        </XStack>

        {/* Amount Card */}
        <Card elevated padding="$6">
          <YStack alignItems="center" gap="$2">
            <XStack gap="$2" alignItems="center">
              <MaterialCommunityIcons name={iconName as any} size={32} color={categoryColor} />
              <Text fontSize="$lg" fontWeight="500">
                {categoryLabel}
              </Text>
            </XStack>
            <Text
              fontSize="$3xl"
              fontWeight="bold"
              color={isVoided ? '$onSurfaceVariant' : '$expense'}
              textDecorationLine={isVoided ? 'line-through' : 'none'}
            >
              {formatCurrency(expense.amount, expense.currency)}
            </Text>
            {isVoided && (
              <Text fontSize="$sm" color="$onSurfaceVariant">
                Đã hủy
              </Text>
            )}
          </YStack>
        </Card>

        {/* Details */}
        <Card elevated>
          <YStack gap="$3">
            <XStack justifyContent="space-between">
              <Text fontSize="$sm" color="$onSurfaceVariant">
                Ngày
              </Text>
              <Text fontSize="$sm">{formattedDate}</Text>
            </XStack>

            <XStack justifyContent="space-between">
              <Text fontSize="$sm" color="$onSurfaceVariant">
                Ví
              </Text>
              <Text fontSize="$sm">{wallet?.name ?? 'Không xác định'}</Text>
            </XStack>

            {expense.description && (
              <YStack gap="$1">
                <Text fontSize="$sm" color="$onSurfaceVariant">
                  Ghi chú
                </Text>
                <Text fontSize="$sm">{expense.description}</Text>
              </YStack>
            )}

            {expense.merchant && (
              <XStack justifyContent="space-between">
                <Text fontSize="$sm" color="$onSurfaceVariant">
                  Cửa hàng
                </Text>
                <Text fontSize="$sm">{expense.merchant}</Text>
              </XStack>
            )}

            <XStack justifyContent="space-between">
              <Text fontSize="$sm" color="$onSurfaceVariant">
                Trạng thái
              </Text>
              <Text fontSize="$sm" color={isVoided ? '$onSurfaceVariant' : '$income'}>
                {isVoided ? 'Đã hủy' : 'Hoạt động'}
              </Text>
            </XStack>
          </YStack>
        </Card>

        {/* Action Buttons */}
        {!isVoided && (
          <YStack gap="$3" marginTop="$auto">
            <Button
              variant="outlined"
              onPress={() => router.push(`/expenses/${expense.id}/edit` as any)}
              icon={<MaterialCommunityIcons name="pencil" size={18} color="#0F766E" />}
            >
              Sửa
            </Button>
            <Button
              theme="red"
              onPress={() => setShowVoidDialog(true)}
              icon={<MaterialCommunityIcons name="cancel" size={18} color="white" />}
            >
              Hủy chi tiêu
            </Button>
          </YStack>
        )}
      </YStack>

      {/* Void Confirmation Dialog */}
      <Dialog open={showVoidDialog} onOpenChange={setShowVoidDialog}>
        <Dialog.Portal>
          <Dialog.Overlay />
          <DialogContent>
            <YStack gap="$4">
              <Text fontSize="$lg" fontWeight="600">
                Hủy chi tiêu?
              </Text>
              <Text fontSize="$sm" color="$onSurfaceVariant">
                Chi tiêu sẽ được đánh dấu là "Đã hủy" và không tính vào báo cáo. Bạn có thể xem lại
                trong lịch sử.
              </Text>
              <XStack gap="$3" justifyContent="flex-end">
                <Button variant="outlined" onPress={() => setShowVoidDialog(false)}>
                  Giữ lại
                </Button>
                <Button theme="red" onPress={handleVoid} loading={voidLoading}>
                  Hủy chi tiêu
                </Button>
              </XStack>
            </YStack>
          </DialogContent>
        </Dialog.Portal>
      </Dialog>
    </YStack>
  );
}

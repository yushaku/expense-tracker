// apps/mobile/app/expenses/[id]/index.tsx
// Expense detail screen
import React, { useEffect, useState } from 'react';
import { YStack, Text, XStack, Card, Button, Dialog, Spinner } from '@expense/ui';
import { useExpenseStore, ExpenseViewModel } from '@/src/stores/expenseStore';
import { useWalletStore } from '@/src/stores/walletStore';
import { useLocalSearchParams, useRouter } from 'expo-router';
import { formatMoney } from '@expense/domain';
import { MaterialCommunityIcons } from '@expo/vector-icons';

const CATEGORY_ICONS: Record<string, string> = {
  cat_food: 'food',
  cat_transport: 'bus',
  cat_shopping: 'shopping',
  cat_entertainment: 'movie-open',
  cat_healthcare: 'medical-bag',
  cat_education: 'school',
  cat_bills: 'file-document-outline',
  cat_other: 'dots-horizontal',
};

const CATEGORY_COLORS: Record<string, string> = {
  cat_food: '#F97316',
  cat_transport: '#3B82F6',
  cat_shopping: '#EC4899',
  cat_entertainment: '#A855F7',
  cat_healthcare: '#EF4444',
  cat_education: '#6366F1',
  cat_bills: '#78716C',
  cat_other: '#64748B',
};

const CATEGORY_LABELS: Record<string, string> = {
  cat_food: 'Ăn uống',
  cat_transport: 'Di chuyển',
  cat_shopping: 'Mua sắm',
  cat_entertainment: 'Giải trí',
  cat_healthcare: 'Y tế',
  cat_education: 'Giáo dục',
  cat_bills: 'Hóa đơn',
  cat_other: 'Khác',
};

export default function ExpenseDetailScreen() {
  const router = useRouter();
  const { id } = useLocalSearchParams<{ id: string }>();
  const { getExpenseById, voidExpense, loadExpenses } = useExpenseStore();
  const { wallets, loadWallets } = useWalletStore();
  const [expense, setExpense] = useState<ExpenseViewModel | null>(null);
  const [loading, setLoading] = useState(true);
  const [showVoidDialog, setShowVoidDialog] = useState(false);
  const [voidLoading, setVoidLoading] = useState(false);

  useEffect(() => {
    Promise.all([loadExpenses(), loadWallets()]).then(() => {
      if (id) {
        setExpense(getExpenseById(id));
      }
      setLoading(false);
    });
  }, [id]);

  const wallet = wallets.find((w) => w.id === expense?.walletId);

  if (loading) {
    return (
      <YStack flex={1} padding="$4" gap="$4" justifyContent="center" alignItems="center">
        <Spinner size="large" color="$primary" />
        <Text color="$onSurfaceVariant">Đang tải...</Text>
      </YStack>
    );
  }

  if (!expense) {
    return (
      <YStack flex={1} padding="$4" gap="$4">
        <Text color="$onSurfaceVariant">Không tìm thấy chi tiêu</Text>
      </YStack>
    );
  }

  const iconName = CATEGORY_ICONS[expense.categoryId] ?? 'dots-horizontal';
  const categoryColor = CATEGORY_COLORS[expense.categoryId] ?? '#64748B';
  const categoryLabel = CATEGORY_LABELS[expense.categoryId] ?? expense.categoryId;
  const isVoided = expense.status === 'voided';

  const formattedDate = new Date(expense.occurredAtUtc).toLocaleDateString('vi-VN', {
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
              {formatMoney({ minorUnits: expense.amountMinor, currency: expense.currency })}
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
              variant="contained"
              onPress={() => setShowVoidDialog(true)}
              backgroundColor="$error"
              icon={<MaterialCommunityIcons name="cancel" size={18} color="white" />}
            >
              Hủy chi tiêu
            </Button>
          </YStack>
        )}
      </YStack>

      <Dialog open={showVoidDialog} onOpenChange={setShowVoidDialog}>
        <Dialog.Portal>
          <Dialog.Overlay />
          <Dialog.Content>
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
                <Button variant="contained" onPress={handleVoid} loading={voidLoading} backgroundColor="$error">
                  Hủy chi tiêu
                </Button>
              </XStack>
            </YStack>
          </Dialog.Content>
        </Dialog.Portal>
      </Dialog>
    </YStack>
  );
}
// apps/mobile/app/incomes/[id]/index.tsx
// Income detail screen

import React, { useEffect, useState } from 'react';
import { YStack, Text, XStack, Card, Button, Dialog } from '@expense/ui';
import {
  useIncomeStore,
  INCOME_TYPE_LABELS,
  INCOME_TYPE_COLORS,
  INCOME_TYPE_ICONS,
} from '@/src/stores/incomeStore';
import { useWalletStore } from '@/src/stores/walletStore';
import { useLocalSearchParams, useRouter } from 'expo-router';
import type { Income } from '@expense/shared';
import { formatCurrency } from '@expense/shared';
import { MaterialCommunityIcons } from '@expo/vector-icons';

export default function IncomeDetailScreen() {
  const router = useRouter();
  const { id } = useLocalSearchParams<{ id: string }>();
  const { getIncomeById, voidIncome, loadIncomes } = useIncomeStore();
  const { wallets, loadWallets } = useWalletStore();
  const [income, setIncome] = useState<Income | null>(null);
  const [showVoidDialog, setShowVoidDialog] = useState(false);
  const [voidLoading, setVoidLoading] = useState(false);

  useEffect(() => {
    loadIncomes().then(() => {
      if (id) {
        setIncome(getIncomeById(id));
      }
    });
    loadWallets();
  }, [id]);

  const wallet = wallets.find((w) => w.id === income?.walletId);

  if (!income) {
    return (
      <YStack flex={1} padding="$4" gap="$4">
        <Text color="$onSurfaceVariant">Không tìm thấy thu nhập</Text>
      </YStack>
    );
  }

  const iconName = INCOME_TYPE_ICONS[income.type] ?? 'dots-horizontal';
  const typeColor = INCOME_TYPE_COLORS[income.type] ?? '#64748B';
  const typeLabel = INCOME_TYPE_LABELS[income.type];
  const isVoided = income.status === 'voided';

  const formattedDate = new Date(income.date).toLocaleDateString('vi-VN', {
    day: '2-digit',
    month: '2-digit',
    year: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
  });

  const handleVoid = async () => {
    setVoidLoading(true);
    try {
      await voidIncome(income.id);
      setShowVoidDialog(false);
      setIncome(getIncomeById(income.id));
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
            Chi tiết thu nhập
          </Text>
        </XStack>

        {/* Amount Card */}
        <Card elevated padding="$6">
          <YStack alignItems="center" gap="$2">
            <XStack gap="$2" alignItems="center">
              <MaterialCommunityIcons name={iconName as any} size={32} color={typeColor} />
              <Text fontSize="$lg" fontWeight="500">
                {typeLabel}
              </Text>
            </XStack>
            <Text
              fontSize="$3xl"
              fontWeight="bold"
              color={isVoided ? '$onSurfaceVariant' : '$income'}
              textDecorationLine={isVoided ? 'line-through' : 'none'}
            >
              +{formatCurrency(income.amount, income.currency)}
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

            {income.source && (
              <XStack justifyContent="space-between">
                <Text fontSize="$sm" color="$onSurfaceVariant">
                  Nguồn thu
                </Text>
                <Text fontSize="$sm">{income.source}</Text>
              </XStack>
            )}

            {income.description && (
              <YStack gap="$1">
                <Text fontSize="$sm" color="$onSurfaceVariant">
                  Ghi chú
                </Text>
                <Text fontSize="$sm">{income.description}</Text>
              </YStack>
            )}

            <XStack justifyContent="space-between">
              <Text fontSize="$sm" color="$onSurfaceVariant">
                Loại
              </Text>
              <Text fontSize="$sm">{typeLabel}</Text>
            </XStack>

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
              onPress={() => router.push(`/incomes/${income.id}/edit` as any)}
              icon={<MaterialCommunityIcons name="pencil" size={18} color="#0F766E" />}
            >
              Sửa
            </Button>
            <Button
              theme="red"
              onPress={() => setShowVoidDialog(true)}
              icon={<MaterialCommunityIcons name="cancel" size={18} color="white" />}
            >
              Hủy thu nhập
            </Button>
          </YStack>
        )}
      </YStack>

      {/* Void Confirmation Dialog */}
      <Dialog open={showVoidDialog} onOpenChange={setShowVoidDialog}>
        <Dialog.Portal>
          <Dialog.Overlay />
          <Dialog.Content>
            <YStack gap="$4">
              <Text fontSize="$lg" fontWeight="600">
                Hủy thu nhập?
              </Text>
              <Text fontSize="$sm" color="$onSurfaceVariant">
                Thu nhập sẽ được đánh dấu là "Đã hủy" và không tính vào báo cáo. Bạn có thể xem lại
                trong lịch sử.
              </Text>
              <XStack gap="$3" justifyContent="flex-end">
                <Button variant="outlined" onPress={() => setShowVoidDialog(false)}>
                  Giữ lại
                </Button>
                <Button theme="red" onPress={handleVoid} loading={voidLoading}>
                  Hủy thu nhập
                </Button>
              </XStack>
            </YStack>
          </Dialog.Content>
        </Dialog.Portal>
      </Dialog>
    </YStack>
  );
}

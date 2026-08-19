// apps/mobile/src/components/expenses/ExpenseForm.tsx
// Create/Edit expense form
import React, { useState } from 'react';
import { YStack, Text, XStack, Input, Card, Button, ScrollView } from '@expense/ui';
import type { ExpenseCategory, Wallet } from '@expense/shared';
import { CATEGORY_LABELS } from '@expense/shared';
import { createMoney, formatMoney } from '@expense/domain';
import { MaterialCommunityIcons } from '@expo/vector-icons';

interface ExpenseFormProps {
  initialData?: {
    id: string;
    amountMinor?: bigint;
    currency?: string;
    category?: ExpenseCategory;
    description?: string;
    date?: string;
    walletId?: string;
  };
  wallets: Wallet[];
  onSubmit: (data: {
    id?: string;
    amountMinor: bigint;
    currency: string;
    category?: ExpenseCategory;
    description?: string;
    walletId?: string;
    clientRequestId?: string;
  }) => Promise<void>;
  onCancel: () => void;
  loading?: boolean;
}

const CATEGORY_LIST: { category: ExpenseCategory; label: string; icon: string }[] = [
  { category: 'food', label: CATEGORY_LABELS.food, icon: 'food' },
  { category: 'transport', label: CATEGORY_LABELS.transport, icon: 'bus' },
  { category: 'shopping', label: CATEGORY_LABELS.shopping, icon: 'shopping' },
  { category: 'entertainment', label: CATEGORY_LABELS.entertainment, icon: 'movie-open' },
  { category: 'healthcare', label: CATEGORY_LABELS.healthcare, icon: 'medical-bag' },
  { category: 'education', label: CATEGORY_LABELS.education, icon: 'school' },
  { category: 'bills', label: CATEGORY_LABELS.bills, icon: 'file-document-outline' },
  { category: 'savings', label: CATEGORY_LABELS.savings, icon: 'piggy-bank' },
  { category: 'other', label: CATEGORY_LABELS.other, icon: 'dots-horizontal' },
];

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

export function ExpenseForm({
  initialData,
  wallets,
  onSubmit,
  onCancel,
  loading,
}: ExpenseFormProps) {
  const [amountStr, setAmountStr] = useState(
    initialData?.amountMinor ? initialData.amountMinor.toString() : '',
  );
  const [category, setCategory] = useState<ExpenseCategory | undefined>(initialData?.category);
  const [description, setDescription] = useState(initialData?.description ?? '');
  const [walletId, setWalletId] = useState(initialData?.walletId ?? '');
  const [errors, setErrors] = useState<Record<string, string>>({});

  const isEdit = !!initialData;
  const currency = 'VND';

  const handleSubmit = async () => {
    const newErrors: Record<string, string> = {};

    // Validate amount using createMoney (BigInt minor units)
    let amountMinor: bigint | null = null;
    if (!amountStr || amountStr.trim() === '') {
      newErrors.amount = 'Số tiền là bắt buộc';
    } else {
      try {
        const money = createMoney(amountStr.trim(), currency);
        amountMinor = money.minorUnits;
      } catch {
        newErrors.amount = 'Số tiền không hợp lệ (phải > 0)';
      }
    }

    if (!category) {
      newErrors.category = 'Vui lòng chọn danh mục';
    }

    if (!walletId) {
      newErrors.walletId = 'Vui lòng chọn ví';
    }

    if (Object.keys(newErrors).length > 0) {
      setErrors(newErrors);
      return;
    }

    try {
      if (isEdit) {
        await onSubmit({
          id: initialData!.id,
          amountMinor: amountMinor!,
          currency,
          ...(category ? { category } : {}),
          ...(description !== undefined ? { description } : {}),
          ...(walletId ? { walletId } : {}),
        });
      } else {
        await onSubmit({
          amountMinor: amountMinor!,
          currency,
          category,
          description,
          walletId,
          clientRequestId: crypto.randomUUID(),
        });
      }
    } catch (err: any) {
      setErrors({ form: err.message ?? 'Thất bại' });
    }
  };

  return (
    <ScrollView>
      <YStack gap="$4" padding="$4" paddingBottom="$12">
        <Text fontSize="$xl" fontWeight="bold">
          {isEdit ? 'Sửa chi tiêu' : 'Thêm chi tiêu'}
        </Text>

        {/* Amount Input */}
        <YStack gap="$2">
          <Text fontSize="$sm" color="$onSurfaceVariant">
            Số tiền (VND)
          </Text>
          <Input
            value={amountStr}
            onChangeText={setAmountStr}
            placeholder="Ví dụ: 50000"
            keyboardType="numeric"
            size="lg"
            accessibilityLabel="Số tiền chi tiêu"
            accessibilityHint="Nhập số tiền bằng đồng Việt Nam"
          />
          {errors.amount && (
            <Text fontSize="$xs" color="$error">
              {errors.amount}
            </Text>
          )}
        </YStack>

        {/* Category Selection */}
        <YStack gap="$2">
          <Text fontSize="$sm" color="$onSurfaceVariant">
            Danh mục
          </Text>
          <XStack gap="$2" flexWrap="wrap">
            {CATEGORY_LIST.map((cat) => (
              <Card
                key={cat.category}
                pressable
                onPress={() => setCategory(cat.category)}
                backgroundColor={category === cat.category ? '$primaryContainer' : '$surface'}
                padding="$2"
                borderRadius="$2"
                accessibilityRole="button"
                accessibilityLabel={cat.label}
                accessibilityState={{ selected: category === cat.category }}
              >
                <XStack gap="$1" alignItems="center">
                  <MaterialCommunityIcons
                    name={cat.icon as any}
                    size={16}
                    color={category === cat.category ? '#0F766E' : CATEGORY_COLORS[cat.category]}
                  />
                  <Text
                    fontSize="$xs"
                    color={category === cat.category ? '$primary' : '$onSurface'}
                  >
                    {cat.label}
                  </Text>
                </XStack>
              </Card>
            ))}
          </XStack>
          {errors.category && (
            <Text fontSize="$xs" color="$error">
              {errors.category}
            </Text>
          )}
        </YStack>

        {/* Wallet Selection */}
        <YStack gap="$2">
          <Text fontSize="$sm" color="$onSurfaceVariant">
            Ví
          </Text>
          <XStack gap="$2" flexWrap="wrap">
            {wallets.map((wallet) => (
              <Card
                key={wallet.id}
                pressable
                onPress={() => setWalletId(wallet.id)}
                backgroundColor={walletId === wallet.id ? '$primaryContainer' : '$surface'}
                padding="$2"
                borderRadius="$2"
                accessibilityRole="button"
                accessibilityLabel={wallet.name}
                accessibilityState={{ selected: walletId === wallet.id }}
              >
                <Text fontSize="$xs" color={walletId === wallet.id ? '$primary' : '$onSurface'}>
                  {wallet.name}
                </Text>
              </Card>
            ))}
          </XStack>
          {errors.walletId && (
            <Text fontSize="$xs" color="$error">
              {errors.walletId}
            </Text>
          )}
        </YStack>

        {/* Description Input */}
        <YStack gap="$2">
          <Text fontSize="$sm" color="$onSurfaceVariant">
            Ghi chú
          </Text>
          <Input
            value={description}
            onChangeText={setDescription}
            placeholder="Mô tả chi tiêu..."
            multiline
            accessibilityLabel="Ghi chú chi tiêu"
          />
        </YStack>

        {errors.form && (
          <Text fontSize="$sm" color="$error" textAlign="center">
            {errors.form}
          </Text>
        )}

        {/* Action Buttons */}
        <XStack gap="$3" paddingTop="$4">
          <Button flex={1} variant="outlined" onPress={onCancel} accessibilityLabel="Hủy">
            Hủy
          </Button>
          <Button
            flex={1}
            variant="contained"
            onPress={handleSubmit}
            loading={loading}
            accessibilityLabel={isEdit ? 'Lưu thay đổi' : 'Thêm chi tiêu'}
          >
            {isEdit ? 'Lưu' : 'Thêm'}
          </Button>
        </XStack>
      </YStack>
    </ScrollView>
  );
}

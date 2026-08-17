// apps/mobile/src/components/incomes/IncomeForm.tsx
// Create/Edit income form

import React, { useState } from 'react';
import { YStack, Text, XStack, Input, Card, Button, ScrollView } from '@expense/ui';
import { IncomeType, Wallet, generateId } from '@expense/shared';
import { MaterialCommunityIcons } from '@expo/vector-icons';
import { INCOME_TYPE_LABELS, INCOME_TYPE_COLORS, INCOME_TYPE_ICONS } from '../../stores/incomeStore';

interface IncomeFormProps {
  initialData?: {
    id: string;
    amount?: number;
    type?: IncomeType;
    source?: string;
    description?: string;
    date?: string;
    walletId?: string;
  };
  wallets: Wallet[];
  onSubmit: (data: any) => Promise<void>;
  onCancel: () => void;
  loading?: boolean;
}

const INCOME_TYPE_LIST: { type: IncomeType; label: string; icon: string }[] = [
  { type: 'salary', label: INCOME_TYPE_LABELS.salary, icon: 'briefcase' },
  { type: 'freelance', label: INCOME_TYPE_LABELS.freelance, icon: 'laptop' },
  { type: 'investment', label: INCOME_TYPE_LABELS.investment, icon: 'chart-line' },
  { type: 'gift', label: INCOME_TYPE_LABELS.gift, icon: 'gift' },
  { type: 'other', label: INCOME_TYPE_LABELS.other, icon: 'dots-horizontal' },
];

export function IncomeForm({
  initialData,
  wallets,
  onSubmit,
  onCancel,
  loading,
}: IncomeFormProps) {
  const [amount, setAmount] = useState(initialData?.amount ? String(initialData.amount) : '');
  const [type, setType] = useState<IncomeType | undefined>(initialData?.type);
  const [source, setSource] = useState(initialData?.source ?? '');
  const [description, setDescription] = useState(initialData?.description ?? '');
  const [walletId, setWalletId] = useState(initialData?.walletId ?? '');
  const [errors, setErrors] = useState<Record<string, string>>({});

  const isEdit = !!initialData;

  const handleSubmit = async () => {
    const newErrors: Record<string, string> = {};

    if (!amount || parseFloat(amount) <= 0) {
      newErrors.amount = 'Số tiền phải > 0';
    }

    if (!type) {
      newErrors.type = 'Vui lòng chọn loại thu nhập';
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
          ...(amount ? { amount: parseFloat(amount) } : {}),
          ...(type ? { type } : {}),
          ...(source !== undefined ? { source } : {}),
          ...(description !== undefined ? { description } : {}),
          ...(walletId ? { walletId } : {}),
        });
      } else {
        await onSubmit({
          amount: parseFloat(amount),
          type,
          source,
          description,
          walletId,
          clientRequestId: generateId(),
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
          {isEdit ? 'Sửa thu nhập' : 'Thêm thu nhập'}
        </Text>

        {/* Amount Input */}
        <YStack gap="$2">
          <Text fontSize="$sm" color="$onSurfaceVariant">
            Số tiền (VND)
          </Text>
          <Input
            value={amount}
            onChangeText={setAmount}
            placeholder="Ví dụ: 5000000"
            keyboardType="numeric"
            size="lg"
          />
          {errors.amount && (
            <Text fontSize="$xs" color="$error">
              {errors.amount}
            </Text>
          )}
        </YStack>

        {/* Type Selection */}
        <YStack gap="$2">
          <Text fontSize="$sm" color="$onSurfaceVariant">
            Loại thu nhập
          </Text>
          <XStack gap="$2" flexWrap="wrap">
            {INCOME_TYPE_LIST.map((item) => (
              <Card
                key={item.type}
                pressable
                onPress={() => setType(item.type)}
                backgroundColor={type === item.type ? '$primaryContainer' : '$surface'}
                padding="$2"
                borderRadius="$2"
              >
                <XStack gap="$1" alignItems="center">
                  <MaterialCommunityIcons
                    name={item.icon as any}
                    size={16}
                    color={type === item.type ? '#0F766E' : INCOME_TYPE_COLORS[item.type]}
                  />
                  <Text
                    fontSize="$xs"
                    color={type === item.type ? '$primary' : '$onSurface'}
                  >
                    {item.label}
                  </Text>
                </XStack>
              </Card>
            ))}
          </XStack>
          {errors.type && (
            <Text fontSize="$xs" color="$error">
              {errors.type}
            </Text>
          )}
        </YStack>

        {/* Source Input */}
        <YStack gap="$2">
          <Text fontSize="$sm" color="$onSurfaceVariant">
            Nguồn thu
          </Text>
          <Input
            value={source}
            onChangeText={setSource}
            placeholder="Ví dụ: Công ty ABC, Khách hàng XYZ..."
          />
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
              >
                <Text
                  fontSize="$xs"
                  color={walletId === wallet.id ? '$primary' : '$onSurface'}
                >
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
            placeholder="Mô tả thu nhập..."
            multiline
          />
        </YStack>

        {errors.form && (
          <Text fontSize="$sm" color="$error" textAlign="center">
            {errors.form}
          </Text>
        )}

        {/* Action Buttons */}
        <XStack gap="$3" paddingTop="$4">
          <Button flex={1} variant="outlined" onPress={onCancel}>
            Hủy
          </Button>
          <Button
            flex={1}
            variant="contained"
            onPress={handleSubmit}
            loading={loading}
          >
            {isEdit ? 'Lưu' : 'Thêm'}
          </Button>
        </XStack>
      </YStack>
    </ScrollView>
  );
}
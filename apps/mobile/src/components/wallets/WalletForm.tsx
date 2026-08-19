// apps/mobile/src/components/wallets/WalletForm.tsx
// Create/Edit wallet form (v3: @expense/domain — BigInt amounts)

import React, { useState } from 'react';
import { YStack, Text, XStack, Input, Card } from '@expense/ui';
import type { WalletType } from '@expense/shared';
import { createMoney } from '@expense/domain';
import { MaterialCommunityIcons } from '@expo/vector-icons';

interface WalletFormProps {
  initialData?: { id: string; name?: string; type?: WalletType; creditLimitMinor?: bigint };
  onSubmit: (data: any) => Promise<void>;
  onCancel: () => void;
  loading?: boolean;
}

const WALLET_TYPES: { type: WalletType; label: string; icon: string }[] = [
  { type: 'cash', label: 'Tiền mặt', icon: 'cash' },
  { type: 'bank', label: 'Tài khoản', icon: 'bank' },
  { type: 'ewallet', label: 'Ví điện tử', icon: 'cellphone' },
  { type: 'credit_card', label: 'Thẻ tín dụng', icon: 'credit-card' },
];

export function WalletForm({ initialData, onSubmit, onCancel, loading }: WalletFormProps) {
  const [name, setName] = useState(initialData?.name ?? '');
  const [type, setType] = useState<WalletType>(initialData?.type ?? 'cash');
  const [creditLimit, setCreditLimit] = useState(
    initialData?.creditLimitMinor ? initialData.creditLimitMinor.toString() : '',
  );
  const [openingBalance, setOpeningBalance] = useState('0');
  const [errors, setErrors] = useState<Record<string, string>>({});

  const isEdit = !!initialData;

  const handleSubmit = async () => {
    const newErrors: Record<string, string> = {};

    if (!name.trim()) {
      newErrors.name = 'Tên ví là bắt buộc';
    }

    // Validate credit limit using createMoney (BigInt minor units)
    let creditLimitMinor: bigint | null = null;

    if (type === 'credit_card') {
      if (!creditLimit || creditLimit.trim() === '') {
        newErrors.creditLimit = 'Hạn mức là bắt buộc';
      } else {
        try {
          creditLimitMinor = createMoney(creditLimit.trim(), 'VND').minorUnits;
        } catch {
          newErrors.creditLimit = 'Số tiền không hợp lệ (phải > 0)';
        }
      }
    }

    // Validate opening balance (allow zero, reject negative)
    let openingBalanceMinor: bigint | null = null;

    if (!isEdit) {
      const balStr = openingBalance.trim();
      if (balStr === '') {
        openingBalanceMinor = 0n;
      } else {
        try {
          // createMoney throws on zero and invalid input
          openingBalanceMinor = createMoney(balStr, 'VND').minorUnits;
        } catch {
          // Handle zero explicitly since createMoney throws on it
          if (balStr === '0' || balStr === '0.0' || balStr === '0.00') {
            openingBalanceMinor = 0n;
          } else if (/^\d+$/.test(balStr)) {
            // Valid non-negative integer for VND (scale 0)
            openingBalanceMinor = BigInt(balStr);
          } else {
            newErrors.openingBalance = 'Số dư không hợp lệ';
          }
        }
      }
    }

    if (Object.keys(newErrors).length > 0) {
      setErrors(newErrors);
      return;
    }

    try {
      if (isEdit) {
        await onSubmit({
          id: initialData!.id,
          name,
          creditLimitMinor: creditLimitMinor ?? 0n,
        });
      } else {
        await onSubmit({
          name,
          type,
          creditLimitMinor: creditLimitMinor ?? 0n,
          openingBalance: openingBalanceMinor ?? 0n,
        });
      }
    } catch (err: any) {
      setErrors({ form: err.message ?? 'Thất bại' });
    }
  };

  return (
    <YStack gap="$4" padding="$4">
      <Text fontSize="$xl" fontWeight="bold">
        {isEdit ? 'Sửa ví' : 'Tạo ví mới'}
      </Text>

      {/* Wallet Type Selection */}
      <YStack gap="$2">
        <Text fontSize="$sm" color="$onSurfaceVariant">
          Loại ví
        </Text>
        <XStack gap="$2" flexWrap="wrap">
          {WALLET_TYPES.map((wt) => (
            <Card
              key={wt.type}
              pressable
              onPress={() => setType(wt.type)}
              backgroundColor={type === wt.type ? '$primaryContainer' : '$surface'}
              padding="$3"
              borderRadius="$3"
            >
              <XStack gap="$2" alignItems="center">
                <MaterialCommunityIcons
                  name={wt.icon as any}
                  size={20}
                  color={type === wt.type ? '#0F766E' : '#49454F'}
                />
                <Text fontSize="$sm" color={type === wt.type ? '$primary' : '$onSurface'}>
                  {wt.label}
                </Text>
              </XStack>
            </Card>
          ))}
        </XStack>
      </YStack>

      {/* Name Input */}
      <YStack gap="$2">
        <Text fontSize="$sm" color="$onSurfaceVariant">
          Tên ví
        </Text>
        <Input
          value={name}
          onChangeText={setName}
          placeholder="Ví dụ: Ví chính, Tiền mặt"
          accessibilityLabel="Tên ví"
          accessibilityHint="Nhập tên cho ví của bạn"
        />
        {errors.name && (
          <Text fontSize="$xs" color="$error">
            {errors.name}
          </Text>
        )}
      </YStack>

      {/* Credit Limit (CC only) */}
      {type === 'credit_card' && (
        <YStack gap="$2">
          <Text fontSize="$sm" color="$onSurfaceVariant">
            Hạn mức tín dụng (VND)
          </Text>
          <Input
            value={creditLimit}
            onChangeText={setCreditLimit}
            placeholder="Ví dụ: 10000000"
            keyboardType="numeric"
            accessibilityLabel="Hạn mức tín dụng"
            accessibilityHint="Nhập hạn mức tín dụng bằng đồng Việt Nam"
          />
          {errors.creditLimit && (
            <Text fontSize="$xs" color="$error">
              {errors.creditLimit}
            </Text>
          )}
        </YStack>
      )}

      {/* Opening Balance (create only) */}
      {!isEdit && (
        <YStack gap="$2">
          <Text fontSize="$sm" color="$onSurfaceVariant">
            Số dư ban đầu (VND)
          </Text>
          <Input
            value={openingBalance}
            onChangeText={setOpeningBalance}
            placeholder="0"
            keyboardType="numeric"
            accessibilityLabel="Số dư ban đầu"
            accessibilityHint="Nhập số dư ban đầu cho ví mới"
          />
          {errors.openingBalance && (
            <Text fontSize="$xs" color="$error">
              {errors.openingBalance}
            </Text>
          )}
        </YStack>
      )}

      {errors.form && (
        <Text fontSize="$sm" color="$error" textAlign="center">
          {errors.form}
        </Text>
      )}
    </YStack>
  );
}

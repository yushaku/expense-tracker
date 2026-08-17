// apps/mobile/src/components/wallets/TransferForm.tsx
// Transfer between wallets form (v3: @expense/domain — BigInt amounts)

import React, { useState } from 'react';
import { YStack, Text, XStack, Input, Card } from '@expense/ui';
import { formatMoney } from '@expense/domain';
import { MaterialCommunityIcons } from '@expo/vector-icons';

interface TransferFormProps {
  wallets: {
    id: string;
    name: string;
    type: 'cash' | 'bank' | 'ewallet' | 'credit_card';
    currency: string;
    creditLimitMinor: bigint;
    balanceMinor: bigint;
  }[];
  onSubmit: (data: {
    fromWalletId: string;
    toWalletId: string;
    amountMinor: bigint;
    note?: string;
    clientRequestId: string;
  }) => Promise<void>;
  onCancel: () => void;
  loading?: boolean;
}

const WALLET_ICONS: Record<string, string> = {
  cash: 'cash',
  bank: 'bank',
  ewallet: 'cellphone',
  credit_card: 'credit-card',
};

export function TransferForm({ wallets, onSubmit, onCancel, loading }: TransferFormProps) {
  const [fromWalletId, setFromWalletId] = useState('');
  const [toWalletId, setToWalletId] = useState('');
  const [amount, setAmount] = useState('');
  const [note, setNote] = useState('');
  const [errors, setErrors] = useState<Record<string, string>>({});

  const fromWallet = wallets.find((w) => w.id === fromWalletId);
  const toWallet = wallets.find((w) => w.id === toWalletId);

  const handleSubmit = async () => {
    const newErrors: Record<string, string> = {};

    if (!fromWalletId) {
      newErrors.fromWalletId = 'Chọn ví nguồn';
    }
    if (!toWalletId) {
      newErrors.toWalletId = 'Chọn ví đích';
    }
    if (fromWalletId === toWalletId) {
      newErrors.toWalletId = 'Ví đích phải khác ví nguồn';
    }
    if (!amount || parseFloat(amount) <= 0) {
      newErrors.amount = 'Số tiền phải > 0';
    }

    if (Object.keys(newErrors).length > 0) {
      setErrors(newErrors);
      return;
    }

    try {
      // Parse to minor units (VND scale = 0)
      const amountMinor = BigInt(Math.round(parseFloat(amount)));

      await onSubmit({
        fromWalletId,
        toWalletId,
        amountMinor,
        note: note || undefined,
        clientRequestId: crypto.randomUUID(),
      });
    } catch (err: any) {
      setErrors({ form: err.message ?? 'Thất bại' });
    }
  };

  return (
    <YStack gap="$4" padding="$4">
      <Text fontSize="$xl" fontWeight="bold">
        Chuyển tiền
      </Text>

      {/* From Wallet */}
      <YStack gap="$2">
        <Text fontSize="$sm" color="$onSurfaceVariant">
          Từ ví
        </Text>
        <XStack gap="$2" flexWrap="wrap">
          {wallets.map((wallet) => (
            <Card
              key={wallet.id}
              pressable
              onPress={() => setFromWalletId(wallet.id)}
              backgroundColor={fromWalletId === wallet.id ? '$primaryContainer' : '$surface'}
              padding="$3"
              borderRadius="$3"
            >
              <XStack gap="$2" alignItems="center">
                <MaterialCommunityIcons
                  name={(WALLET_ICONS[wallet.type] ?? 'wallet') as any}
                  size={20}
                  color={fromWalletId === wallet.id ? '#0F766E' : '#49454F'}
                />
                <Text fontSize="$sm" color={fromWalletId === wallet.id ? '$primary' : '$onSurface'}>
                  {wallet.name}
                </Text>
              </XStack>
            </Card>
          ))}
        </XStack>
        {errors.fromWalletId && (
          <Text fontSize="$xs" color="$error">
            {errors.fromWalletId}
          </Text>
        )}
        {fromWallet && (
          <Text fontSize="$xs" color="$onSurfaceVariant">
            Số dư:{' '}
            {formatMoney({ minorUnits: fromWallet.balanceMinor, currency: fromWallet.currency })}
          </Text>
        )}
      </YStack>

      {/* To Wallet */}
      <YStack gap="$2">
        <Text fontSize="$sm" color="$onSurfaceVariant">
          Đến ví
        </Text>
        <XStack gap="$2" flexWrap="wrap">
          {wallets.map((wallet) => (
            <Card
              key={wallet.id}
              pressable
              onPress={() => setToWalletId(wallet.id)}
              backgroundColor={toWalletId === wallet.id ? '$primaryContainer' : '$surface'}
              padding="$3"
              borderRadius="$3"
            >
              <XStack gap="$2" alignItems="center">
                <MaterialCommunityIcons
                  name={(WALLET_ICONS[wallet.type] ?? 'wallet') as any}
                  size={20}
                  color={toWalletId === wallet.id ? '#0F766E' : '#49454F'}
                />
                <Text fontSize="$sm" color={toWalletId === wallet.id ? '$primary' : '$onSurface'}>
                  {wallet.name}
                </Text>
              </XStack>
            </Card>
          ))}
        </XStack>
        {errors.toWalletId && (
          <Text fontSize="$xs" color="$error">
            {errors.toWalletId}
          </Text>
        )}
      </YStack>

      {/* Amount */}
      <YStack gap="$2">
        <Text fontSize="$sm" color="$onSurfaceVariant">
          Số tiền (VND)
        </Text>
        <Input
          value={amount}
          onChangeText={setAmount}
          placeholder="Ví dụ: 500000"
          keyboardType="numeric"
        />
        {errors.amount && (
          <Text fontSize="$xs" color="$error">
            {errors.amount}
          </Text>
        )}
      </YStack>

      {/* Note */}
      <YStack gap="$2">
        <Text fontSize="$sm" color="$onSurfaceVariant">
          Ghi chú (tùy chọn)
        </Text>
        <Input value={note} onChangeText={setNote} placeholder="Ví dụ: Trả nợ thẻ tín dụng" />
      </YStack>

      {errors.form && (
        <Text fontSize="$sm" color="$error" textAlign="center">
          {errors.form}
        </Text>
      )}
    </YStack>
  );
}

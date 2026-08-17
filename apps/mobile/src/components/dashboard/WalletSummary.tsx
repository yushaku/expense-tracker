// apps/mobile/src/components/dashboard/WalletSummary.tsx
// Wallet balances overview (v3: @expense/domain)

import { Card, XStack, YStack, Text } from '@expense/ui';
import type { WalletBalanceItem } from '../../stores/dashboardStore';
import { formatMoney } from '@expense/domain';
import { MaterialCommunityIcons } from '@expo/vector-icons';

interface WalletSummaryProps {
  wallets: WalletBalanceItem[];
  currency?: string;
}

const WALLET_ICONS: Record<string, string> = {
  cash: 'cash',
  bank: 'bank',
  ewallet: 'cellphone',
  credit_card: 'credit-card',
};

export function WalletSummary({ wallets, currency = 'VND' }: WalletSummaryProps) {
  if (wallets.length === 0) {
    return (
      <Card elevated>
        <YStack gap="$2" alignItems="center" paddingVertical="$4">
          <Text fontSize="$sm" color="$onSurfaceVariant">
            Chưa có ví nào
          </Text>
        </YStack>
      </Card>
    );
  }

  return (
    <Card elevated>
      <YStack gap="$3">
        <Text fontSize="$lg" fontWeight="600">
          Ví của bạn
        </Text>
        <YStack gap="$2">
          {wallets.map((wallet) => (
            <WalletRow key={wallet.id} wallet={wallet} currency={currency} />
          ))}
        </YStack>
      </YStack>
    </Card>
  );
}

interface WalletRowProps {
  wallet: WalletBalanceItem;
  currency: string;
}

function WalletRow({ wallet, currency }: WalletRowProps) {
  const iconName = WALLET_ICONS[wallet.type] ?? 'wallet';
  const isCreditCard = wallet.type === 'credit_card';

  return (
    <XStack justifyContent="space-between" alignItems="center" paddingVertical="$1">
      <XStack gap="$2" alignItems="center" flex={1}>
        <MaterialCommunityIcons name={iconName as any} size={20} color="#0F766E" />
        <YStack flex={1}>
          <Text fontSize="$sm" fontWeight="500" numberOfLines={1}>
            {wallet.name}
          </Text>
          {isCreditCard && wallet.creditLimitMinor > 0n && (
            <Text fontSize="$xs" color="$onSurfaceVariant">
              Hạn mức: {formatMoney({ minorUnits: wallet.creditLimitMinor, currency })}
            </Text>
          )}
        </YStack>
      </XStack>
      <Text
        fontSize="$md"
        fontWeight="600"
        color={isCreditCard ? '$expense' : wallet.balanceMinor >= 0n ? '$income' : '$expense'}
      >
        {formatMoney({
          minorUnits: wallet.balanceMinor >= 0n ? wallet.balanceMinor : -wallet.balanceMinor,
          currency,
        })}
      </Text>
    </XStack>
  );
}

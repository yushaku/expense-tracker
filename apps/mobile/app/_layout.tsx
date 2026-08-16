import { Stack } from 'expo-router';
import { TamaguiProvider } from '@expense/ui';
import { config } from '@expense/ui';
import { StatusBar } from 'expo-status-bar';

export default function RootLayout() {
  return (
    <TamaguiProvider config={config}>
      <StatusBar style="auto" />
      <Stack>
        <Stack.Screen name="index" options={{ title: 'Chi tiêu' }} />
        <Stack.Screen name="add" options={{ title: 'Thêm chi tiêu' }} />
        <Stack.Screen name="expenses" options={{ title: 'Chi tiêu' }} />
        <Stack.Screen name="expenses/index" options={{ title: 'Chi tiêu' }} />
        <Stack.Screen name="expenses/new" options={{ title: 'Thêm chi tiêu' }} />
        <Stack.Screen name="expenses/[id]" options={{ title: 'Chi tiết chi tiêu' }} />
        <Stack.Screen name="expenses/[id]/edit" options={{ title: 'Sửa chi tiêu' }} />
        <Stack.Screen name="wallets" options={{ title: 'Ví' }} />
        <Stack.Screen name="wallets/index" options={{ title: 'Ví của tôi' }} />
        <Stack.Screen name="wallets/[id]" options={{ title: 'Chi tiết ví' }} />
        <Stack.Screen name="wallets/new" options={{ title: 'Tạo ví' }} />
        <Stack.Screen name="wallets/transfer" options={{ title: 'Chuyển tiền' }} />
      </Stack>
    </TamaguiProvider>
  );
}
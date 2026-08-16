// apps/mobile/App.tsx
import { Stack } from 'expo-router';
import { PaperProvider } from 'react-native-paper';
import { StatusBar } from 'expo-status-bar';

export default function App() {
  return (
    <PaperProvider>
      <StatusBar style="auto" />
      <Stack>
        <Stack.Screen name="index" options={{ title: 'Chi tiêu' }} />
        <Stack.Screen name="add" options={{ title: 'Thêm chi tiêu' }} />
        <Stack.Screen name="stats" options={{ title: 'Thống kê' }} />
        <Stack.Screen name="settings" options={{ title: 'Cài đặt' }} />
      </Stack>
    </PaperProvider>
  );
}

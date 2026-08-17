import { Stack } from 'expo-router';

export default function IncomesLayout() {
  return (
    <Stack>
      <Stack.Screen name="index" options={{ title: 'Thu nhập' }} />
      <Stack.Screen name="new" options={{ title: 'Thêm thu nhập' }} />
      <Stack.Screen name="[id]" options={{ headerShown: false }} />
    </Stack>
  );
}

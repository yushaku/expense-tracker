import { Stack } from 'expo-router';

export default function ExpensesLayout() {
  return (
    <Stack>
      <Stack.Screen name="index" options={{ title: 'Chi tiêu' }} />
      <Stack.Screen name="new" options={{ title: 'Thêm chi tiêu' }} />
      <Stack.Screen name="[id]" options={{ headerShown: false }} />
    </Stack>
  );
}

import { Stack } from 'expo-router';

export default function IncomeIdLayout() {
  return (
    <Stack>
      <Stack.Screen name="index" options={{ title: 'Chi tiết thu nhập' }} />
      <Stack.Screen name="edit" options={{ title: 'Sửa thu nhập' }} />
    </Stack>
  );
}

import { Stack } from 'expo-router';

export default function ExpenseIdLayout() {
  return (
    <Stack>
      <Stack.Screen name="index" options={{ title: 'Chi tiết chi tiêu' }} />
      <Stack.Screen name="edit" options={{ title: 'Sửa chi tiêu' }} />
    </Stack>
  );
}

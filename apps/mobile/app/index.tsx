import { YStack, Text } from '@expense/ui';

export default function HomeScreen() {
  return (
    <YStack flex={1} padding="$4" gap="$4">
      <Text fontSize="$xl" fontWeight="bold">
        Expense Tracker
      </Text>
      <Text>Chưa có chi tiêu nào. Nhấn + để thêm.</Text>
    </YStack>
  );
}
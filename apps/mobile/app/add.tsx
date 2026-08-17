import { YStack, Text } from '@expense/ui';

export default function AddScreen() {
  return (
    <YStack flex={1} padding="$4" gap="$4">
      <Text fontSize="$xl" fontWeight="bold">
        Thêm chi tiêu
      </Text>
      <Text opacity={0.6}>Form sẽ thêm ở bước tiếp theo.</Text>
    </YStack>
  );
}

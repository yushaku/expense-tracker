// apps/mobile/app/settings/index.tsx
// Settings screen — app configuration

import React from 'react';
import { ScrollView, Text, XStack, YStack, Card, Button } from '@expense/ui';
import { MaterialCommunityIcons } from '@expo/vector-icons';
import { useRouter } from 'expo-router';

export default function SettingsScreen() {
  const router = useRouter();

  return (
    <ScrollView flex={1} backgroundColor="$background">
      <YStack gap="$4" padding="$4">
        <Text fontSize="$xl" fontWeight="bold">
          Cài đặt
        </Text>

        {/* Appearance */}
        <Card elevated padding="$4">
          <YStack gap="$3">
            <Text fontSize="$md" fontWeight="600">
              Giao diện
            </Text>

            <XStack justifyContent="space-between" alignItems="center">
              <YStack>
                <Text fontSize="$sm">Chủ đề</Text>
                <Text fontSize="$xs" color="$muted">
                  Sáng / Tối
                </Text>
              </YStack>
              <Button variant="outlined" size="sm">
                Hệ thống
              </Button>
            </XStack>

            <XStack justifyContent="space-between" alignItems="center">
              <YStack>
                <Text fontSize="$sm">Ngôn ngữ</Text>
                <Text fontSize="$xs" color="$muted">
                  Tiếng Việt
                </Text>
              </YStack>
              <Button variant="outlined" size="sm">
                Đổi ngôn ngữ
              </Button>
            </XStack>
          </YStack>
        </Card>

        {/* Data Management */}
        <Card elevated padding="$4">
          <YStack gap="$3">
            <Text fontSize="$md" fontWeight="600">
              Dữ liệu
            </Text>

            <XStack justifyContent="space-between" alignItems="center">
              <YStack>
                <Text fontSize="$sm">Sao lưu</Text>
                <Text fontSize="$xs" color="$muted">
                  Xuất file sao lưu JSON
                </Text>
              </YStack>
              <Button variant="contained" size="sm">
                Sao lưu ngay
              </Button>
            </XStack>

            <XStack justifyContent="space-between" alignItems="center">
              <YStack>
                <Text fontSize="$sm">Khôi phục</Text>
                <Text fontSize="$xs" color="$muted">
                  Tải lên bản sao lưu
                </Text>
              </YStack>
              <Button variant="outlined" size="sm">
                Khôi phục
              </Button>
            </XStack>
          </YStack>
        </Card>

        {/* About */}
        <Card elevated padding="$4">
          <YStack gap="$3">
            <Text fontSize="$md" fontWeight="600">
              Về ứng dụng
            </Text>

            <XStack alignItems="center" gap="$3">
              <MaterialCommunityIcons name="information" size={24} color="#8caaee" />
              <YStack>
                <Text fontSize="$sm" fontWeight="600">
                  Expense Tracker
                </Text>
                <Text fontSize="$xs" color="$muted">
                  Phiên bản 1.0.0
                </Text>
              </YStack>
            </XStack>
          </YStack>
        </Card>
      </YStack>
    </ScrollView>
  );
}

// apps/mobile/app/_layout.tsx
// Root layout — Bottom tab navigation with 5 tabs (iOS-style)

import { Tabs } from 'expo-router';
import { config } from '@expense/ui';
import { useTheme, Text, TamaguiProvider } from 'tamagui';
import { StatusBar } from 'expo-status-bar';
import { MaterialCommunityIcons } from '@expo/vector-icons';

function TabBarLabel({ children, focused }: { children: string; focused: boolean }) {
  return (
    <Text fontSize="$xs" color={focused ? '$primary' : '$onSurfaceMuted'}>
      {children}
    </Text>
  );
}

function TabLayout() {
  const theme = useTheme();

  return (
    <Tabs
      screenOptions={{
        headerShown: false,
        tabBarActiveTintColor: theme.primary?.val ?? '#81c8be',
        tabBarInactiveTintColor: theme.onSurfaceMuted?.val ?? '#737994',
        tabBarStyle: {
          backgroundColor: theme.surface?.val ?? '#292c3c',
          borderTopColor: theme.outline?.val ?? '#51576d',
          borderTopWidth: 0.5,
          height: 60,
          paddingBottom: 8,
          paddingTop: 6,
        },
        tabBarLabelStyle: {
          fontSize: 11,
          fontWeight: '500',
        },
      }}
    >
      <Tabs.Screen
        name="index"
        options={{
          title: 'Tổng quan',
          tabBarIcon: ({ focused, color }) => (
            <MaterialCommunityIcons
              name={focused ? 'home' : 'home-outline'}
              size={24}
              color={color}
            />
          ),
          tabBarLabel: ({ focused }) => (
            <TabBarLabel focused={focused}>Tổng quan</TabBarLabel>
          ),
        }}
      />
      <Tabs.Screen
        name="transactions"
        options={{
          title: 'Giao dịch',
          tabBarIcon: ({ focused, color }) => (
            <MaterialCommunityIcons
              name={focused ? 'swap-horizontal' : 'swap-horizontal'}
              size={24}
              color={color}
            />
          ),
          tabBarLabel: ({ focused }) => (
            <TabBarLabel focused={focused}>Giao dịch</TabBarLabel>
          ),
        }}
      />
      <Tabs.Screen
        name="wallets"
        options={{
          title: 'Ví',
          tabBarIcon: ({ focused, color }) => (
            <MaterialCommunityIcons
              name={focused ? 'wallet' : 'wallet-outline'}
              size={24}
              color={color}
            />
          ),
          tabBarLabel: ({ focused }) => (
            <TabBarLabel focused={focused}>Ví</TabBarLabel>
          ),
        }}
      />
      <Tabs.Screen
        name="investments"
        options={{
          title: 'Đầu tư',
          tabBarIcon: ({ focused, color }) => (
            <MaterialCommunityIcons
              name={focused ? 'chart-line' : 'chart-line-variant'}
              size={24}
              color={color}
            />
          ),
          tabBarLabel: ({ focused }) => (
            <TabBarLabel focused={focused}>Đầu tư</TabBarLabel>
          ),
        }}
      />
      <Tabs.Screen
        name="settings"
        options={{
          title: 'Cài đặt',
          tabBarIcon: ({ focused, color }) => (
            <MaterialCommunityIcons
              name={focused ? 'cog' : 'cog-outline'}
              size={24}
              color={color}
            />
          ),
          tabBarLabel: ({ focused }) => (
            <TabBarLabel focused={focused}>Cài đặt</TabBarLabel>
          ),
        }}
      />
    </Tabs>
  );
}

export default function RootLayout() {
  return (
    <TamaguiProvider config={config}>
      <StatusBar style="auto" />
      <TabLayout />
    </TamaguiProvider>
  );
}
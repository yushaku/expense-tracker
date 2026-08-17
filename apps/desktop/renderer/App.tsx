import React from 'react';
import { createRoot } from 'react-dom/client';
import { TamaguiProvider, YStack, Text } from '@expense/ui';
import { config } from '@expense/ui';

function App() {
  return (
    <TamaguiProvider config={config}>
      <YStack flex={1} padding="$6" gap="$4" alignItems="center" justifyContent="center">
        <Text fontSize="$2xl" fontWeight="bold">
          Expense Tracker
        </Text>
        <Text>Desktop app placeholder. Coming soon.</Text>
      </YStack>
    </TamaguiProvider>
  );
}

const container = document.getElementById('root');
const root = createRoot(container);
root.render(<App />);

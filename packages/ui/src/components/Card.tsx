import { Card as TamaguiCard, styled } from 'tamagui';

export const Card = styled(TamaguiCard, {
  name: 'Card',
  backgroundColor: '$surface',
  borderRadius: '$3',
  padding: '$4',
  variants: {
    elevated: {
      true: {
        shadowColor: '#000',
        shadowOffset: { width: 0, height: 2 },
        shadowOpacity: 0.1,
        shadowRadius: 4,
        elevation: 2,
      },
    },
    pressable: {
      true: {
        cursor: 'pointer',
        pressStyle: {
          backgroundColor: '$surfaceVariant',
        },
      },
    },
  } as const,
});
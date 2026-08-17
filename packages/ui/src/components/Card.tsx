import { Card as TamaguiCard, styled } from 'tamagui';

export const Card = styled(TamaguiCard, {
  name: 'Card',
  backgroundColor: '$surface',
  borderRadius: '$4',
  padding: '$4',
  borderWidth: 1,
  borderColor: '$outline',
  transition: 'all 150ms ease-out',
  variants: {
    elevated: {
      true: {
        shadowColor: '$shadow',
        shadowOffset: { width: 0, height: 2 },
        shadowOpacity: 0.06,
        shadowRadius: 8,
        elevation: 3,
        borderWidth: 0,
      },
    },
    pressable: {
      true: {
        cursor: 'pointer',
        pressStyle: {
          backgroundColor: '$surfaceVariant',
          scale: 0.98,
        },
      },
    },
    size: {
      sm: {
        padding: '$3',
      },
      md: {
        padding: '$4',
      },
      lg: {
        padding: '$6',
      },
    },
  } as const,
  defaultVariants: {
    size: 'md',
  },
});

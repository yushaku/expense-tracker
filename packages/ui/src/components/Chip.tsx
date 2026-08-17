import { XStack, Text, styled } from 'tamagui';

export const Chip = styled(XStack, {
  name: 'Chip',
  alignItems: 'center',
  justifyContent: 'center',
  paddingHorizontal: '$3',
  paddingVertical: '$1',
  borderRadius: '$2',
  backgroundColor: '$surfaceVariant',
  gap: '$1',
  cursor: 'pointer',
  transition: 'all 150ms ease-out',
  pressStyle: {
    opacity: 0.8,
    scale: 0.97,
  },
  variants: {
    selected: {
      true: {
        backgroundColor: '$primaryContainer',
      },
    },
    size: {
      sm: {
        height: 24,
        paddingHorizontal: '$2',
        fontSize: 12,
      },
      md: {
        height: 32,
        paddingHorizontal: '$3',
        fontSize: 14,
      },
      lg: {
        height: 40,
        paddingHorizontal: '$4',
        fontSize: 15,
      },
    },
    variant: {
      default: {
        backgroundColor: '$surfaceVariant',
      },
      income: {
        backgroundColor: '$incomeSoft',
      },
      expense: {
        backgroundColor: '$expenseSoft',
      },
      warning: {
        backgroundColor: '$warningSoft',
      },
    },
  } as const,
  defaultVariants: {
    size: 'md',
    variant: 'default',
  },
});

export const ChipText = styled(Text, {
  name: 'ChipText',
  fontFamily: '$body',
  fontWeight: '500',
  color: '$onSurface',
  variants: {
    selected: {
      true: {
        color: '$primary',
        fontWeight: '600',
      },
    },
    variant: {
      default: {
        color: '$onSurface',
      },
      income: {
        color: '$income',
      },
      expense: {
        color: '$expense',
      },
      warning: {
        color: '$warning',
      },
    },
  } as const,
});

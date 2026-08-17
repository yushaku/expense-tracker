import { XStack, Text, styled } from 'tamagui';

export const Chip = styled(XStack, {
  name: 'Chip',
  alignItems: 'center',
  justifyContent: 'center',
  paddingHorizontal: '$2',
  paddingVertical: '$1',
  borderRadius: '$2',
  backgroundColor: '$surfaceVariant',
  variants: {
    selected: {
      true: {
        backgroundColor: '$primaryContainer',
      },
    },
    size: {
      sm: {
        height: 24,
        fontSize: 12,
      },
      md: {
        height: 32,
        fontSize: 14,
      },
    },
  } as const,
  defaultVariants: {
    size: 'md',
  },
});

export const ChipText = styled(Text, {
  name: 'ChipText',
  color: '$onSurface',
  variants: {
    selected: {
      true: {
        color: '$primary',
      },
    },
  } as const,
});

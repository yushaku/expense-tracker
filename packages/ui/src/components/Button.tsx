import { styled, Button as TamaguiButton } from 'tamagui';

export const Button = styled(TamaguiButton, {
  name: 'Button',
  variants: {
    variant: {
      contained: {
        backgroundColor: '$primary',
        color: '$onPrimary',
        pressStyle: {
          backgroundColor: '$primary',
          opacity: 0.8,
        },
      },
      outlined: {
        backgroundColor: 'transparent',
        borderWidth: 1,
        borderColor: '$outline',
        color: '$onSurface',
        pressStyle: {
          backgroundColor: '$surfaceVariant',
        },
      },
      text: {
        backgroundColor: 'transparent',
        color: '$primary',
        pressStyle: {
          backgroundColor: '$primaryContainer',
        },
      },
    },
    size: {
      sm: {
        height: 32,
        paddingHorizontal: 12,
        fontSize: 14,
      },
      md: {
        height: 44,
        paddingHorizontal: 16,
        fontSize: 16,
      },
      lg: {
        height: 56,
        paddingHorizontal: 24,
        fontSize: 18,
      },
    },
  } as const,
  defaultVariants: {
    variant: 'contained',
    size: 'md',
  },
});

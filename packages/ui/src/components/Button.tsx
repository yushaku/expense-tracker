import { styled, Button as TamaguiButton, Text } from 'tamagui';

export const Button = styled(TamaguiButton, {
  name: 'Button',
  fontFamily: '$body',
  fontWeight: '600',
  borderRadius: '$3',
  cursor: 'pointer',
  transition: 'all 150ms ease-out',
  pressStyle: {
    opacity: 0.85,
    scale: 0.98,
  },
  variants: {
    variant: {
      primary: {
        backgroundColor: '$primary',
        color: '$onPrimary',
        pressStyle: {
          backgroundColor: '$primary',
          opacity: 0.85,
        },
      },
      contained: {
        backgroundColor: '$primary',
        color: '$onPrimary',
        pressStyle: {
          backgroundColor: '$primary',
          opacity: 0.85,
        },
      },
      secondary: {
        backgroundColor: '$secondaryContainer',
        color: '$secondary',
        pressStyle: {
          backgroundColor: '$surfaceVariant',
        },
      },
      outlined: {
        backgroundColor: 'transparent',
        color: '$primary',
        borderWidth: 1,
        borderColor: '$primary',
        pressStyle: {
          backgroundColor: '$primaryContainer',
        },
      },
      ghost: {
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
        paddingHorizontal: '$3',
        fontSize: 13,
        borderRadius: '$2',
      },
      md: {
        height: 44,
        paddingHorizontal: '$4',
        fontSize: 15,
        borderRadius: '$3',
      },
      lg: {
        height: 52,
        paddingHorizontal: '$6',
        fontSize: 17,
        borderRadius: '$4',
      },
    },
    fullWidth: {
      true: {
        width: '100%',
      },
    },
    disabled: {
      true: {
        opacity: 0.5,
        pointerEvents: 'none',
      },
    },
  } as const,
  defaultVariants: {
    variant: 'primary',
    size: 'md',
  },
});

export const ButtonText = styled(Text, {
  name: 'ButtonText',
  fontFamily: '$body',
  fontWeight: '600',
  color: 'inherit',
});

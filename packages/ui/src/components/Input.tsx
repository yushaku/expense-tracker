import { Input as TamaguiInput, styled, XStack, Text } from 'tamagui';

export const Input = styled(TamaguiInput, {
  name: 'Input',
  backgroundColor: '$surface',
  borderWidth: 1,
  borderColor: '$outline',
  borderRadius: '$3',
  paddingHorizontal: '$3',
  paddingVertical: '$2',
  fontSize: 16,
  fontFamily: '$body',
  color: '$onSurface',
  transition: 'border-color 150ms ease-out',
  focusStyle: {
    borderColor: '$primary',
    borderWidth: 1.5,
  },
  variants: {
    size: {
      sm: {
        height: 36,
        fontSize: 14,
        paddingHorizontal: '$2',
      },
      md: {
        height: 44,
        fontSize: 16,
        paddingHorizontal: '$3',
      },
      lg: {
        height: 52,
        fontSize: 18,
        paddingHorizontal: '$4',
      },
    },
    error: {
      true: {
        borderColor: '$error',
        focusStyle: {
          borderColor: '$error',
        },
      },
    },
    disabled: {
      true: {
        opacity: 0.5,
        backgroundColor: '$surfaceVariant',
      },
    },
  } as const,
  defaultVariants: {
    size: 'md',
  },
});

export const InputLabel = styled(Text, {
  name: 'InputLabel',
  fontFamily: '$body',
  fontSize: 13,
  fontWeight: '500',
  color: '$onSurfaceVariant',
  marginBottom: '$1',
});

export const InputError = styled(Text, {
  name: 'InputError',
  fontFamily: '$body',
  fontSize: 12,
  color: '$error',
  marginTop: '$1',
});

export const InputWrapper = styled(XStack, {
  name: 'InputWrapper',
  flexDirection: 'column',
  gap: '$1',
});

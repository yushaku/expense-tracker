import { Input as TamaguiInput, styled } from 'tamagui';

export const Input = styled(TamaguiInput, {
  name: 'Input',
  backgroundColor: '$surface',
  borderWidth: 1,
  borderColor: '$outline',
  borderRadius: '$2',
  paddingHorizontal: '$3',
  paddingVertical: '$2',
  fontSize: 16,
  color: '$onSurface',
  focusStyle: {
    borderColor: '$primary',
  },
  variants: {
    size: {
      sm: {
        height: 32,
        fontSize: 14,
      },
      md: {
        height: 44,
        fontSize: 16,
      },
      lg: {
        height: 56,
        fontSize: 18,
      },
    },
  } as const,
  defaultVariants: {
    size: 'md',
  },
});
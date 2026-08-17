import { Button, styled } from 'tamagui';

export const FAB = styled(Button, {
  name: 'FAB',
  position: 'absolute',
  right: '$4',
  bottom: '$4',
  width: 56,
  height: 56,
  borderRadius: '$8',
  backgroundColor: '$primary',
  color: '$onPrimary',
  alignItems: 'center',
  justifyContent: 'center',
  shadowColor: '$shadow',
  shadowOffset: { width: 0, height: 4 },
  shadowOpacity: 0.2,
  shadowRadius: 12,
  elevation: 6,
  cursor: 'pointer',
  transition: 'all 150ms ease-out',
  pressStyle: {
    backgroundColor: '$primary',
    opacity: 0.85,
    scale: 0.95,
  },
  variants: {
    size: {
      sm: {
        width: 44,
        height: 44,
        borderRadius: '$6',
      },
      md: {
        width: 56,
        height: 56,
        borderRadius: '$8',
      },
      lg: {
        width: 64,
        height: 64,
        borderRadius: '$8',
      },
    },
    position: {
      'bottom-right': {
        right: '$4',
        bottom: '$4',
      },
      'bottom-left': {
        left: '$4',
        bottom: '$4',
      },
      'bottom-center': {
        alignSelf: 'center',
        bottom: '$4',
      },
    },
  } as const,
  defaultVariants: {
    size: 'md',
    position: 'bottom-right',
  },
});

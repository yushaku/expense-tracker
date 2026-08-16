import { Button, styled } from 'tamagui';

export const FAB = styled(Button, {
  name: 'FAB',
  position: 'absolute',
  right: '$4',
  bottom: '$4',
  width: 56,
  height: 56,
  borderRadius: 28,
  backgroundColor: '$primary',
  color: '$onPrimary',
  alignItems: 'center',
  justifyContent: 'center',
  shadowColor: '#000',
  shadowOffset: { width: 0, height: 4 },
  shadowOpacity: 0.3,
  shadowRadius: 8,
  elevation: 8,
  pressStyle: {
    backgroundColor: '$primary',
    opacity: 0.8,
  },
});
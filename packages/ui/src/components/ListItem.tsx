import { XStack, Text, styled } from 'tamagui';

export const ListItem = styled(XStack, {
  name: 'ListItem',
  alignItems: 'center',
  paddingVertical: '$3',
  paddingHorizontal: '$4',
  borderBottomWidth: 1,
  borderBottomColor: '$surfaceVariant',
  minHeight: 56,
  pressStyle: {
    backgroundColor: '$surfaceVariant',
  },
  variants: {
    pressable: {
      true: {
        cursor: 'pointer',
      },
    },
  } as const,
});

export const ListItemText = styled(Text, {
  name: 'ListItemText',
  flex: 1,
  color: '$onSurface',
  fontSize: 16,
});
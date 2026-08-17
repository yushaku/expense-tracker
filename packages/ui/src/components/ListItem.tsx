import { XStack, Text, styled } from 'tamagui';

export const ListItem = styled(XStack, {
  name: 'ListItem',
  alignItems: 'center',
  paddingVertical: '$3',
  paddingHorizontal: '$4',
  gap: '$3',
  minHeight: 60,
  backgroundColor: '$surface',
  borderBottomWidth: 1,
  borderBottomColor: '$surfaceVariant',
  cursor: 'pointer',
  transition: 'background-color 150ms ease-out',
  pressStyle: {
    backgroundColor: '$surfaceVariant',
  },
  variants: {
    pressable: {
      true: {
        cursor: 'pointer',
      },
    },
    size: {
      sm: {
        minHeight: 48,
        paddingVertical: '$2',
      },
      md: {
        minHeight: 60,
        paddingVertical: '$3',
      },
      lg: {
        minHeight: 72,
        paddingVertical: '$4',
      },
    },
  } as const,
  defaultVariants: {
    size: 'md',
  },
});

export const ListItemIcon = styled(XStack, {
  name: 'ListItemIcon',
  width: 40,
  height: 40,
  borderRadius: '$3',
  alignItems: 'center',
  justifyContent: 'center',
  backgroundColor: '$surfaceVariant',
  variants: {
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
      primary: {
        backgroundColor: '$primaryContainer',
      },
    },
  } as const,
  defaultVariants: {
    variant: 'default',
  },
});

export const ListItemContent = styled(XStack, {
  name: 'ListItemContent',
  flex: 1,
  flexDirection: 'column',
  gap: '$0.5',
  justifyContent: 'center',
});

export const ListItemTitle = styled(Text, {
  name: 'ListItemTitle',
  fontFamily: '$body',
  fontSize: 16,
  fontWeight: '500',
  color: '$onSurface',
});

export const ListItemSubtitle = styled(Text, {
  name: 'ListItemSubtitle',
  fontFamily: '$body',
  fontSize: 13,
  color: '$onSurfaceMuted',
});

export const ListItemAmount = styled(Text, {
  name: 'ListItemAmount',
  fontFamily: '$body',
  fontSize: 16,
  fontWeight: '600',
  color: '$onSurface',
  variants: {
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
    },
  } as const,
  defaultVariants: {
    variant: 'default',
  },
});

import { Dialog as TamaguiDialog, styled, YStack, Text, XStack } from 'tamagui';

export const Dialog = styled(TamaguiDialog, {
  name: 'Dialog',
});

export const DialogContent = styled(TamaguiDialog.Content, {
  name: 'DialogContent',
  backgroundColor: '$surface',
  borderRadius: '$5',
  padding: '$6',
  maxWidth: 400,
  width: '90%',
  shadowColor: '$shadow',
  shadowOffset: { width: 0, height: 8 },
  shadowOpacity: 0.15,
  shadowRadius: 24,
  elevation: 8,
});

export const DialogHeader = styled(YStack, {
  name: 'DialogHeader',
  gap: '$2',
  marginBottom: '$4',
});

export const DialogTitle = styled(Text, {
  name: 'DialogTitle',
  fontFamily: '$heading',
  fontSize: 20,
  fontWeight: '600',
  color: '$onSurface',
});

export const DialogDescription = styled(Text, {
  name: 'DialogDescription',
  fontFamily: '$body',
  fontSize: 14,
  color: '$onSurfaceVariant',
  lineHeight: 20,
});

export const DialogBody = styled(YStack, {
  name: 'DialogBody',
  gap: '$3',
  marginVertical: '$4',
});

export const DialogFooter = styled(XStack, {
  name: 'DialogFooter',
  gap: '$3',
  justifyContent: 'flex-end',
  marginTop: '$4',
});

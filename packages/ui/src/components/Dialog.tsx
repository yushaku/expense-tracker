import { Dialog as TamaguiDialog, styled } from 'tamagui';

export const Dialog = styled(TamaguiDialog, {
  name: 'Dialog',
});

export const DialogContent = styled(TamaguiDialog.Content, {
  name: 'DialogContent',
  backgroundColor: '$surface',
  borderRadius: '$4',
  padding: '$4',
  maxWidth: 400,
  width: '90%',
});

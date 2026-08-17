export { config } from './tamagui.config';
export {
  YStack,
  XStack,
  Stack,
  Text,
  Theme,
  useTheme,
  Dialog,
  ScrollView,
  AnimatePresence,
  Spinner,
  TamaguiProvider,
} from 'tamagui';
export type { TextProps, DialogProps } from 'tamagui';

// Custom styled components (variants like elevated/pressable)
export { Button, Button as AppButton } from './src/components/Button';
export { Card, Card as AppCard } from './src/components/Card';
export {
  Input,
  Input as AppInput,
  InputLabel,
  InputError,
  InputWrapper,
} from './src/components/Input';
export {
  Dialog as AppDialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
  DialogDescription,
  DialogBody,
  DialogFooter,
} from './src/components/Dialog';
export { FAB } from './src/components/FAB';
export { Chip, ChipText } from './src/components/Chip';
export {
  ListItem,
  ListItemIcon,
  ListItemContent,
  ListItemTitle,
  ListItemSubtitle,
  ListItemAmount,
} from './src/components/ListItem';

// Theme tokens
export { lightColors, darkColors } from './src/theme/colors';
export type { ColorTokens } from './src/theme/colors';
export { spacing, radius, size, zIndex, animation, shadow } from './src/theme/tokens';
export {
  fonts,
  fontSize,
  lineHeight,
  fontWeight,
  letterSpacing,
  typography,
} from './src/theme/typography';

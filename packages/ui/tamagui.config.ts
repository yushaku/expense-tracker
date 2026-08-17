import { createTamagui, createTokens } from 'tamagui';
import { createInterFont } from '@tamagui/font-inter';
import { shorthands } from '@tamagui/shorthands';
import { themes, tokens as defaultTokens } from '@tamagui/themes';
import { lightColors, darkColors } from './src/theme/colors';
import { spacing, radius, size, zIndex } from './src/theme/tokens';

const tokens = createTokens({
  ...defaultTokens,
  color: {
    ...defaultTokens.color,
    ...lightColors,
  },
  space: {
    ...defaultTokens.space,
    ...spacing,
  },
  size: {
    ...defaultTokens.size,
    ...size,
  },
  radius: {
    ...defaultTokens.radius,
    ...radius,
  },
  zIndex: {
    ...defaultTokens.zIndex,
    ...zIndex,
  },
});

const lightTheme = {
  background: tokens.color.background,
  color: tokens.color.onSurface,
  primary: tokens.color.primary,
  onPrimary: tokens.color.onPrimary,
  primaryContainer: tokens.color.primaryContainer,
  primarySoft: tokens.color.primarySoft,
  secondary: tokens.color.secondary,
  onSecondary: tokens.color.onSecondary,
  secondaryContainer: tokens.color.secondaryContainer,
  income: tokens.color.income,
  incomeSoft: tokens.color.incomeSoft,
  expense: tokens.color.expense,
  expenseSoft: tokens.color.expenseSoft,
  savings: tokens.color.savings,
  savingsSoft: tokens.color.savingsSoft,
  transfer: tokens.color.transfer,
  warning: tokens.color.warning,
  warningSoft: tokens.color.warningSoft,
  success: tokens.color.success,
  error: tokens.color.error,
  surface: tokens.color.surface,
  surfaceVariant: tokens.color.surfaceVariant,
  surfaceRaised: tokens.color.surfaceRaised,
  onSurface: tokens.color.onSurface,
  onSurfaceVariant: tokens.color.onSurfaceVariant,
  onSurfaceMuted: tokens.color.onSurfaceMuted,
  outline: tokens.color.outline,
  outlineStrong: tokens.color.outlineStrong,
  shadow: tokens.color.shadow,
};

const darkTheme = {
  background: darkColors.background,
  color: darkColors.onSurface,
  primary: darkColors.primary,
  onPrimary: darkColors.onPrimary,
  primaryContainer: darkColors.primaryContainer,
  primarySoft: darkColors.primarySoft,
  secondary: darkColors.secondary,
  onSecondary: darkColors.onSecondary,
  secondaryContainer: darkColors.secondaryContainer,
  income: darkColors.income,
  incomeSoft: darkColors.incomeSoft,
  expense: darkColors.expense,
  expenseSoft: darkColors.expenseSoft,
  savings: darkColors.savings,
  savingsSoft: darkColors.savingsSoft,
  transfer: darkColors.transfer,
  warning: darkColors.warning,
  warningSoft: darkColors.warningSoft,
  success: darkColors.success,
  error: darkColors.error,
  surface: darkColors.surface,
  surfaceVariant: darkColors.surfaceVariant,
  surfaceRaised: darkColors.surfaceRaised,
  onSurface: darkColors.onSurface,
  onSurfaceVariant: darkColors.onSurfaceVariant,
  onSurfaceMuted: darkColors.onSurfaceMuted,
  outline: darkColors.outline,
  outlineStrong: darkColors.outlineStrong,
  shadow: darkColors.shadow,
};

export const config = createTamagui({
  themes: {
    light: lightTheme,
    dark: darkTheme,
  },
  tokens,
  shorthands,
  fonts: {
    heading: createInterFont(),
    body: createInterFont(),
  },
});

export type Conf = typeof config;

declare module 'tamagui' {
  interface TamaguiCustomConfig extends Conf {}
}

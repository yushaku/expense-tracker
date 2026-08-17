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
    true: spacing['4'], // default = $4
  },
  size: {
    ...defaultTokens.size,
    ...size,
    true: size['4'], // default = $4
  },
  radius: {
    ...defaultTokens.radius,
    ...radius,
    true: radius['2'], // default = $2
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
  // Catppuccin Latte raw palette tokens
  rosewater: tokens.color.rosewater,
  flamingo: tokens.color.flamingo,
  pink: tokens.color.pink,
  mauve: tokens.color.mauve,
  red: tokens.color.red,
  maroon: tokens.color.maroon,
  peach: tokens.color.peach,
  yellow: tokens.color.yellow,
  green: tokens.color.green,
  teal: tokens.color.teal,
  sky: tokens.color.sky,
  sapphire: tokens.color.sapphire,
  blue: tokens.color.blue,
  lavender: tokens.color.lavender,
  text: tokens.color.text,
  subtext1: tokens.color.subtext1,
  subtext0: tokens.color.subtext0,
  overlay2: tokens.color.overlay2,
  overlay1: tokens.color.overlay1,
  overlay0: tokens.color.overlay0,
  surface2: tokens.color.surface2,
  surface1: tokens.color.surface1,
  surface0: tokens.color.surface0,
  base: tokens.color.base,
  mantle: tokens.color.mantle,
  crust: tokens.color.crust,
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
  // Catppuccin Frappé raw palette tokens
  rosewater: darkColors.rosewater,
  flamingo: darkColors.flamingo,
  pink: darkColors.pink,
  mauve: darkColors.mauve,
  red: darkColors.red,
  maroon: darkColors.maroon,
  peach: darkColors.peach,
  yellow: darkColors.yellow,
  green: darkColors.green,
  teal: darkColors.teal,
  sky: darkColors.sky,
  sapphire: darkColors.sapphire,
  blue: darkColors.blue,
  lavender: darkColors.lavender,
  text: darkColors.text,
  subtext1: darkColors.subtext1,
  subtext0: darkColors.subtext0,
  overlay2: darkColors.overlay2,
  overlay1: darkColors.overlay1,
  overlay0: darkColors.overlay0,
  surface2: darkColors.surface2,
  surface1: darkColors.surface1,
  surface0: darkColors.surface0,
  base: darkColors.base,
  mantle: darkColors.mantle,
  crust: darkColors.crust,
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

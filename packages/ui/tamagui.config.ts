import { createTamagui, createTokens } from 'tamagui';
import { createInterFont } from '@tamagui/font-inter';
import { shorthands } from '@tamagui/shorthands';
import { themes, tokens as defaultTokens } from '@tamagui/themes';

const tokens = createTokens({
  ...defaultTokens,
  color: {
    ...defaultTokens.color,
    // Brand
    primary: '#0F766E',
    onPrimary: '#FFFFFF',
    primaryContainer: '#CCFBF1',
    secondary: '#475569',
    onSecondary: '#FFFFFF',
    secondaryContainer: '#E2E8F0',
    // Semantic money
    income: '#15803D',
    expense: '#DC2626',
    savings: '#0369A1',
    transfer: '#64748B',
    warning: '#D97706',
    // Surfaces
    background: '#FFFBFE',
    surface: '#FFFFFF',
    surfaceVariant: '#F1F5F9',
    onSurface: '#1C1B1F',
    onSurfaceVariant: '#49454F',
    outline: '#79747E',
    error: '#B3261E',
  },
  space: {
    '0': 0, '1': 4, '2': 8, '3': 12, '4': 16,
    '5': 20, '6': 24, '8': 32, '10': 40, '12': 48,
  },
  size: {
    '0': 0, '1': 4, '2': 8, '3': 12, '4': 16,
    '5': 20, '6': 24, '8': 32, '10': 40, '12': 48,
  },
  radius: {
    '0': 0, '1': 4, '2': 8, '3': 12, '4': 16, '6': 24,
  },
  zIndex: { '0': 0, '1': 100, '2': 200, '3': 300, '4': 400, '5': 500 },
});

const lightTheme = {
  background: tokens.color.background,
  color: tokens.color.onSurface,
  primary: tokens.color.primary,
  onPrimary: tokens.color.onPrimary,
  primaryContainer: tokens.color.primaryContainer,
  secondary: tokens.color.secondary,
  onSecondary: tokens.color.onSecondary,
  secondaryContainer: tokens.color.secondaryContainer,
  income: tokens.color.income,
  expense: tokens.color.expense,
  savings: tokens.color.savings,
  transfer: tokens.color.transfer,
  warning: tokens.color.warning,
  surface: tokens.color.surface,
  surfaceVariant: tokens.color.surfaceVariant,
  onSurface: tokens.color.onSurface,
  onSurfaceVariant: tokens.color.onSurfaceVariant,
  outline: tokens.color.outline,
  error: tokens.color.error,
};

const darkTheme = {
  background: '#121212',
  color: '#E6E1E5',
  primary: '#2DD4BF',
  onPrimary: '#042F2E',
  primaryContainer: '#134E4A',
  secondary: '#94A3B8',
  onSecondary: '#1C1B1F',
  secondaryContainer: '#334155',
  income: '#4ADE80',
  expense: '#F87171',
  savings: '#38BDF8',
  transfer: '#94A3B8',
  warning: '#FBBF24',
  surface: '#1C1B1F',
  surfaceVariant: '#334155',
  onSurface: '#E6E1E5',
  onSurfaceVariant: '#CAC4D0',
  outline: '#938F99',
  error: '#F2B8B5',
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
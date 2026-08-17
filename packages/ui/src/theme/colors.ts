export const lightColors = {
  // Brand Primary
  primary: '#0F766E',
  onPrimary: '#FFFFFF',
  primaryContainer: '#CCFBF1',
  primarySoft: '#99F6E4',

  // Secondary
  secondary: '#475569',
  onSecondary: '#FFFFFF',
  secondaryContainer: '#E2E8F0',

  // Semantic Money
  income: '#15803D',
  incomeSoft: '#DCFCE7',
  expense: '#DC2626',
  expenseSoft: '#FEE2E2',
  savings: '#0369A1',
  savingsSoft: '#DBEAFE',
  transfer: '#64748B',
  warning: '#D97706',
  warningSoft: '#FEF3C7',
  success: '#15803D',
  error: '#B3261E',

  // Surfaces
  background: '#F2F2F7',
  surface: '#FFFFFF',
  surfaceVariant: '#F1F5F9',
  surfaceRaised: '#FFFFFF',

  // Text
  onSurface: '#1C1B1F',
  onSurfaceVariant: '#49454F',
  onSurfaceMuted: '#6B7280',

  // Border / Outline
  outline: '#D1D5DB',
  outlineStrong: '#9CA3AF',

  // Shadow
  shadow: '#000000',
} as const;

export const darkColors = {
  // Brand Primary
  primary: '#2DD4BF',
  onPrimary: '#042F2E',
  primaryContainer: '#134E4A',
  primarySoft: '#14534F',

  // Secondary
  secondary: '#94A3B8',
  onSecondary: '#1C1B1F',
  secondaryContainer: '#334155',

  // Semantic Money
  income: '#4ADE80',
  incomeSoft: '#14532D',
  expense: '#F87171',
  expenseSoft: '#7F1D1D',
  savings: '#38BDF8',
  savingsSoft: '#0C4A6E',
  transfer: '#94A3B8',
  warning: '#FBBF24',
  warningSoft: '#78350F',
  success: '#4ADE80',
  error: '#F2B8B5',

  // Surfaces
  background: '#0F0F0F',
  surface: '#1C1B1F',
  surfaceVariant: '#2C2C2E',
  surfaceRaised: '#2C2C2E',

  // Text
  onSurface: '#E6E1E5',
  onSurfaceVariant: '#CAC4D0',
  onSurfaceMuted: '#9CA3AF',

  // Border / Outline
  outline: '#3F3F46',
  outlineStrong: '#52525B',

  // Shadow
  shadow: '#000000',
} as const;

export type ColorTokens = typeof lightColors;

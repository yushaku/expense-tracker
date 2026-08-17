// Catppuccin Frappé (dark) & Latte (light) palette
// https://github.com/catppuccin/catppuccin

export const lightColors = {
  // Catppuccin Latte (light mode) — raw palette
  rosewater: '#dc8a78',
  flamingo: '#dd7878',
  pink: '#ea76cb',
  mauve: '#8839ef',
  red: '#d20f39',
  maroon: '#e64553',
  peach: '#fe640b',
  yellow: '#df8e1d',
  green: '#40a02b',
  teal: '#179299',
  sky: '#04a5e5',
  sapphire: '#209fb5',
  blue: '#1e66f5',
  lavender: '#7287fd',
  text: '#4c4f69',
  subtext1: '#5c5f77',
  subtext0: '#6c6f85',
  overlay2: '#7c7f93',
  overlay1: '#8c8fa1',
  overlay0: '#9ca0b0',
  surface2: '#acb0be',
  surface1: '#bcc0cc',
  surface0: '#ccd0da',
  base: '#eff1f5',
  mantle: '#e6e9ef',
  crust: '#dce0e8',

  // Brand Primary (Teal)
  primary: '#179299',
  onPrimary: '#eff1f5',
  primaryContainer: '#bcc0cc',
  primarySoft: '#acb0be',

  // Secondary (Overlay1)
  secondary: '#8c8fa1',
  onSecondary: '#eff1f5',
  secondaryContainer: '#ccd0da',

  // Semantic Money
  income: '#40a02b',
  incomeSoft: '#ccd0da',
  expense: '#d20f39',
  expenseSoft: '#e6e9ef',
  savings: '#1e66f5',
  savingsSoft: '#ccd0da',
  transfer: '#6c6f85',
  warning: '#df8e1d',
  warningSoft: '#e6e9ef',
  success: '#40a02b',
  error: '#e64553',

  // Surfaces
  background: '#eff1f5',
  surface: '#e6e9ef',
  surfaceVariant: '#dce0e8',
  surfaceRaised: '#e6e9ef',

  // Text
  onSurface: '#4c4f69',
  onSurfaceVariant: '#5c5f77',
  onSurfaceMuted: '#9ca0b0',

  // Border / Outline
  outline: '#bcc0cc',
  outlineStrong: '#8c8fa1',

  // Shadow
  shadow: '#4c4f69',
} as const;

export const darkColors = {
  // Catppuccin Frappé (dark mode) — raw palette
  rosewater: '#f2d5dc',
  flamingo: '#eebebe',
  pink: '#f4b8e4',
  mauve: '#ca9ee6',
  red: '#e78284',
  maroon: '#ea999c',
  peach: '#ef9f76',
  yellow: '#e5c890',
  green: '#a6d189',
  teal: '#81c8be',
  sky: '#99d1db',
  sapphire: '#85c1dc',
  blue: '#8caaee',
  lavender: '#babbf1',
  text: '#c6d0f5',
  subtext1: '#b5bfe2',
  subtext0: '#a5adce',
  overlay2: '#949cbb',
  overlay1: '#838ba7',
  overlay0: '#737994',
  surface2: '#626880',
  surface1: '#51576d',
  surface0: '#414559',
  base: '#303446',
  mantle: '#292c3c',
  crust: '#232634',

  // Brand Primary (Teal)
  primary: '#81c8be',
  onPrimary: '#303446',
  primaryContainer: '#51576d',
  primarySoft: '#414559',

  // Secondary (Overlay1)
  secondary: '#838ba7',
  onSecondary: '#303446',
  secondaryContainer: '#414559',

  // Semantic Money
  income: '#a6d189',
  incomeSoft: '#414559',
  expense: '#e78284',
  expenseSoft: '#414559',
  savings: '#8caaee',
  savingsSoft: '#414559',
  transfer: '#a5adce',
  warning: '#e5c890',
  warningSoft: '#414559',
  success: '#a6d189',
  error: '#ea999c',

  // Surfaces
  background: '#303446',
  surface: '#292c3c',
  surfaceVariant: '#232634',
  surfaceRaised: '#292c3c',

  // Text
  onSurface: '#c6d0f5',
  onSurfaceVariant: '#b5bfe2',
  onSurfaceMuted: '#737994',

  // Border / Outline
  outline: '#51576d',
  outlineStrong: '#838ba7',

  // Shadow
  shadow: '#000000',
} as const;

export type ColorTokens = typeof lightColors;

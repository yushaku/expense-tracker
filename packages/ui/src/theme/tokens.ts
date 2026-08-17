/**
 * Design tokens — spacing, radius, zIndex, animation.
 * Base unit: 4px.
 */

export const spacing = {
  '0': 0,
  '0.5': 2,
  '1': 4,
  '1.5': 6,
  '2': 8,
  '3': 12,
  '4': 16,
  '5': 20,
  '6': 24,
  '8': 32,
  '10': 40,
  '12': 48,
  '16': 64,
  '20': 80,
} as const;

export const radius = {
  '0': 0,
  '1': 4,
  '2': 8,
  '3': 10,
  '4': 12,
  '5': 16,
  '6': 20,
  '8': 24,
  full: 9999,
} as const;

export const size = {
  '0': 0,
  '1': 4,
  '2': 8,
  '3': 12,
  '4': 16,
  '5': 20,
  '6': 24,
  '8': 32,
  '10': 40,
  '12': 48,
  '16': 64,
  '20': 80,
} as const;

export const zIndex = {
  '0': 0,
  '1': 100,
  '2': 200,
  '3': 300,
  '4': 400,
  '5': 500,
} as const;

export const animation = {
  quick: '150ms ease-out',
  normal: '250ms ease-out',
  slow: '400ms ease-out',
  spring: {
    type: 'spring',
    damping: 20,
    stiffness: 300,
  },
  springBouncy: {
    type: 'spring',
    damping: 15,
    stiffness: 250,
  },
} as const;

export const shadow = {
  sm: {
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 1 },
    shadowOpacity: 0.05,
    shadowRadius: 2,
    elevation: 1,
  },
  md: {
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.08,
    shadowRadius: 8,
    elevation: 3,
  },
  lg: {
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 4 },
    shadowOpacity: 0.12,
    shadowRadius: 16,
    elevation: 5,
  },
  xl: {
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 8 },
    shadowOpacity: 0.15,
    shadowRadius: 24,
    elevation: 8,
  },
} as const;

export type SpacingToken = keyof typeof spacing;
export type RadiusToken = keyof typeof radius;
export type SizeToken = keyof typeof size;
export type ZIndexToken = keyof typeof zIndex;

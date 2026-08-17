# Design System — Expense Tracker

> Practical UI guide for a solo MVP on **iPhone + Mac (Electron)** using **Tamagui**.
> Shared components across mobile + desktop. Ship fast; refine later.

**Stack:** Expo ~50 · Tamagui · Expo Router · Electron · `@expo/vector-icons` (Material Community Icons)

**Related:** `docs/features/03-dashboard.md`, `docs/phases/01-phase-1.md`, `packages/shared` categories

---

## 1. Design Principles

| Principle              | What it means for MVP                                                                                                |
| ---------------------- | -------------------------------------------------------------------------------------------------------------------- |
| **Cash clarity**       | Money is the hero. Amounts are large, signed, and color-coded. Labels stay secondary.                                |
| **Tamagui first**      | Use Tamagui components (`Button`, `Card`, `Input`, `FAB`, `List`, `Dialog`, `Chip`). Shared across mobile + desktop. |
| **One primary action** | Each screen has one obvious next step (usually FAB or filled button). Avoid competing CTAs.                          |
| **Scan in 2 seconds**  | Dashboard: cash flow → category chart → wallets. Lists: amount + category + date.                                    |
| **Light & dark equal** | Design both from day one via Tamagui theme tokens. No hard-coded hex in screens.                                     |
| **iPhone primary**     | Design for thumb reach and small width first; Mac gets more density, not a separate visual language.                 |
| **Locale-aware**       | UI copy can be Vietnamese; numbers use `vi-VN` / VND formatting from `@expense/shared`.                              |

**Non-goals (MVP):** custom illustration set, complex motion design system, multiple brand personalities, pixel-perfect desktop chrome.

---

## 2. Color Palette

Build on Tamagui themes. Override only what finance needs.

### Brand (Primary / Secondary)

| Token                | Light                 | Dark                  | Role                                      |
| -------------------- | --------------------- | --------------------- | ----------------------------------------- |
| `primary`            | `#0F766E` (teal-700)  | `#2DD4BF` (teal-400)  | Brand, primary buttons, FAB, selected tab |
| `onPrimary`          | `#FFFFFF`             | `#042F2E`             | Text/icons on primary                     |
| `primaryContainer`   | `#CCFBF1`             | `#134E4A`             | Soft highlights, selected chips           |
| `secondary`          | `#475569` (slate-600) | `#94A3B8` (slate-400) | Secondary actions, neutral accents        |
| `secondaryContainer` | `#E2E8F0`             | `#334155`             | Secondary surfaces                        |

Teal reads as "money / trust" without the generic purple-AI look.

### Surfaces & Text

| Token              | Light     | Dark      |
| ------------------ | --------- | --------- |
| `background`       | `#FFFBFE` | `#121212` |
| `surface`          | `#FFFFFF` | `#1C1B1F` |
| `surfaceVariant`   | `#F1F5F9` | `#334155` |
| `onSurface`        | `#1C1B1F` | `#E6E1E5` |
| `onSurfaceVariant` | `#49454F` | `#CAC4D0` |
| `outline`          | `#79747E` | `#938F99` |
| `error`            | `#B3261E` | `#F2B8B5` |

### Semantic money colors (custom tokens)

| Token      | Light            | Dark      | Use                                |
| ---------- | ---------------- | --------- | ---------------------------------- |
| `income`   | `#15803D`        | `#4ADE80` | Income amounts, positive cash flow |
| `expense`  | `#DC2626`        | `#F87171` | Expense amounts, deficit           |
| `savings`  | `#0369A1`        | `#38BDF8` | Savings rate, savings category     |
| `transfer` | `#64748B`        | `#94A3B8` | Transfers (neutral; not "spend")   |
| `warning`  | `#D97706`        | `#FBBF24` | Budget near limit (Phase 1.5)      |
| `success`  | same as `income` | same      | Confirmations                      |

**Rules**

- Expense amounts: `expense` (+ optional leading `−`).
- Income amounts: `income` (+ optional `+`).
- Cash flow: sign drives color (`≥ 0` → income, `< 0` → expense).
- Voided rows: `onSurfaceVariant` + strikethrough; never semantic green/red.
- Charts: category hues below.

### Category colors (expense)

Stable mapping for chips + pie/bar segments:

| Category        | Hex (light) | Icon hint       |
| --------------- | ----------- | --------------- |
| `food`          | `#F97316`   | food            |
| `transport`     | `#3B82F6`   | car / bus       |
| `shopping`      | `#EC4899`   | shopping        |
| `entertainment` | `#A855F7`   | movie           |
| `healthcare`    | `#EF4444`   | medical-bag     |
| `education`     | `#6366F1`   | school          |
| `bills`         | `#78716C`   | file-document   |
| `savings`       | `#0369A1`   | piggy-bank      |
| `other`         | `#64748B`   | dots-horizontal |

Dark mode: same hues, bumped ~1–2 steps lighter for contrast.

---

## 3. Typography

Use Tamagui's type scale via `<Text fontSize="$X">` and variants.

### Scale (mobile)

| Size   | px  | Use                 |
| ------ | --- | ------------------- |
| `$xs`  | 12  | Timestamps, meta    |
| `$sm`  | 14  | Descriptions, hints |
| `$md`  | 16  | Body, form          |
| `$lg`  | 18  | Section headers     |
| `$xl`  | 20  | Screen titles       |
| `$2xl` | 24  | Dashboard headers   |
| `$3xl` | 30  | Dashboard cash flow |
| `$4xl` | 36  | Onboarding hero     |

### Money typography

| Context                  | Size          | Weight  |
| ------------------------ | ------------- | ------- |
| Dashboard cash flow      | `$3xl`–`$4xl` | Bold    |
| List row amount          | `$lg`         | Medium  |
| Supporting currency note | `$xs`         | Regular |

Always format with shared helpers (`formatCurrency`), never raw `toString()`.

### Mobile vs desktop

|                | iPhone      | Mac (Electron)            |
| -------------- | ----------- | ------------------------- |
| Body           | `$sm`–`$md` | `$sm`–`$md` (same)        |
| Page title     | `$xl`       | `$2xl` OK                 |
| Density        | Comfortable | Slightly tighter          |
| Max text width | Full bleed  | ~720–960px content column |

---

## 4. Spacing System

**Base unit: 4px.** Use multiples only.

| Token | px  | Common use                   |
| ----- | --- | ---------------------------- |
| `$0`  | 0   | —                            |
| `$1`  | 4   | Icon–label gap               |
| `$2`  | 8   | Chip gap, tight stacks       |
| `$3`  | 12  | Input padding vertical       |
| `$4`  | 16  | Screen padding, card padding |
| `$5`  | 20  | —                            |
| `$6`  | 24  | Section gap                  |
| `$8`  | 32  | Empty-state offset           |
| `$10` | 40  | —                            |
| `$12` | 48  | FAB clearance above tab bar  |

**Screen padding:** `$4` mobile; `$6` Mac content area.
**Card margin:** `$2` between cards.
**FAB:** `$4` from right/bottom safe area.

---

## 5. Component Library

Prefer Tamagui primitives. All components shared across mobile + desktop.

### Buttons

| Kind        | Tamagui                        | When                                  |
| ----------- | ------------------------------ | ------------------------------------- |
| Primary     | `<Button variant="contained">` | Save expense/income, confirm transfer |
| Secondary   | `<Button variant="outlined">`  | Cancel, secondary path                |
| Tertiary    | `<Button variant="text">`      | Edit, "See all"                       |
| Destructive | `<Button theme="red">`         | Void transaction                      |

- One contained button per form.
- Full-width primary on iPhone forms; auto-width OK on Mac.
- Loading: `loading` + `disabled` on submit.

### Cards

- `<Card>` for dashboard metrics and expense rows
- Pressable cards → `onPress` to detail
- Metric cards: big number + short label + optional delta

### Inputs

- `<Input>` for amount, note, merchant
- Amount: numeric keyboard (`decimal-pad`)
- Selects: `<Select>` for category, wallet, income vs expense toggle
- Date: Tamagui date picker; show `vi-VN` date

### Chips

- `<Chip>` for category filter & display
- Selected filter: `selected` + `primaryContainer`

### FAB

- Single screen FAB: `plus` → Add flow (`/add`)
- Color: `tokens.color.primary`
- With bottom tabs: sit above tab bar; don't cover list content

### Lists

- `<List.Item>` for wallets & settings
- Transaction feed with left category icon, center text, right amount

### Modals / dialogs

- Confirm void: `<Dialog>` ("Hoàn tác được trong lịch sử; không tính vào báo cáo")
- Filters (Mac): `<Dialog>` or side panel; mobile: full-screen stack route
- Avoid nested modals

### Navigation chrome

- Stack headers: Expo Router defaults; title from screen
- Tabs: bottom tabs (iPhone), side rail (Mac ≥768px)

---

## 6. Icons

**Set:** Material Community Icons via `@expo/vector-icons`.

### System / nav

| Action       | Icon                   |
| ------------ | ---------------------- |
| Add          | `plus`                 |
| Dashboard    | `view-dashboard`       |
| Transactions | `format-list-bulleted` |
| Wallets      | `wallet`               |
| Settings     | `cog`                  |
| Search       | `magnify`              |
| Transfer     | `bank-transfer`        |
| Income       | `trending-up`          |
| Expense      | `trending-down`        |
| Void         | `cancel`               |
| Edit         | `pencil`               |

### Category icons

| Category      | Icon name               |
| ------------- | ----------------------- |
| food          | `food`                  |
| transport     | `bus` / `car`           |
| shopping      | `shopping`              |
| entertainment | `movie-open`            |
| healthcare    | `medical-bag`           |
| education     | `school`                |
| bills         | `file-document-outline` |
| savings       | `piggy-bank`            |
| other         | `dots-horizontal`       |

### Wallet type icons

| Type        | Icon          |
| ----------- | ------------- |
| cash        | `cash`        |
| bank        | `bank`        |
| ewallet     | `cellphone`   |
| credit_card | `credit-card` |

**Size:** 24dp default; 20 in dense lists; 40 in empty states.

---

## 7. Layout

### Screen structure

```
┌─────────────────────────────┐
│ Safe area / App bar         │
│ Title + optional actions    │
├─────────────────────────────┤
│ Content (Scroll/FlatList)   │
│  padding: 16                │
│  sections spaced by 24      │
├─────────────────────────────┤
│ Bottom tabs (iPhone)        │
│ FAB overlays content        │
└─────────────────────────────┘
```

### Phase 1 information architecture

| Tab / stack          | Routes                                | Purpose                                             |
| -------------------- | ------------------------------------- | --------------------------------------------------- |
| **Home / Dashboard** | `/`                                   | Cash flow, category chart, savings, wallet snapshot |
| **Transactions**     | `/transactions`, `/transactions/[id]` | List, search, detail, edit                          |
| **Wallets**          | `/wallets`, transfer modal/route      | Balances + transfer                                 |
| **Add**              | `/add` (stack modal)                  | Expense / income entry                              |
| **Settings**         | `/settings`                           | Export, auth, appearance                            |

### Bottom tabs + stack

- **iPhone:** `Tabs` for Dashboard / Transactions / Wallets / Settings; `Stack` push for Add, Detail, Edit, Transfer.
- **Add:** present as modal stack (`presentation: 'modal'`) from FAB.
- **Mac:** same route tree; tabs become **side rail** when `width ≥ 768`.

### Breakpoints

| Name     | Width   | Behavior                      |
| -------- | ------- | ----------------------------- |
| Compact  | `< 768` | Phone layout, bottom tabs     |
| Expanded | `≥ 768` | Side rail; 2-column dashboard |

---

## 8. Data Visualization

**MVP libs:** `react-native-chart-kit` or `victory-native`. One library only.

| Chart              | Data                            | Notes                            |
| ------------------ | ------------------------------- | -------------------------------- |
| Category breakdown | `%` of expenses                 | Donut or horizontal bar; hide 0% |
| Cash flow trend    | Daily/weekly net (Phase 1.5 OK) | Line; Phase 1 can skip           |
| Savings rate       | Single %                        | Big number + thin progress/ring  |

**Rules**

- Use category color tokens; don't randomize.
- Tooltips: mobile = tap; Mac = hover or tap.
- Empty: replace chart with short empty state.

---

## 9. Animations

Keep motion **subtle and optional**.

| Interaction         | Motion                    |
| ------------------- | ------------------------- |
| Button / list press | Tamagui default press     |
| Screen push         | Expo Router default       |
| Modal add           | Slide up                  |
| FAB                 | No bounce; static is fine |
| Chart enter         | Optional fade (200–300ms) |
| Void success        | Snackbar; no confetti     |

---

## 10. Accessibility

| Rule                | Spec                                                          |
| ------------------- | ------------------------------------------------------------- |
| Contrast            | Text vs surface ≥ **4.5:1**; large money figures ≥ **3:1**    |
| Touch targets       | Min **44×44 pt**                                              |
| Labels              | `accessibilityLabel` on FAB, icon buttons, chart segments     |
| Dynamic type        | Prefer Tamagui variants; don't fix absolute sizes             |
| Color ≠ sole signal | Amount sign (`+`/`−`) + color; voided = strikethrough + label |
| Reduce motion       | Respect OS setting                                            |

---

## 11. Platform Differences (iPhone vs Mac)

| Concern       | iPhone                 | Mac (Electron)                                    |
| ------------- | ---------------------- | ------------------------------------------------- |
| Primary input | Thumb, one column      | Pointer + keyboard                                |
| Nav           | Bottom tabs            | Side rail at ≥768px                               |
| Density       | `$4` padding           | `$6` page padding, denser lists                   |
| Keyboard      | Avoid covering CTA     | Tab order: Amount → Category → Wallet → Save      |
| Safe areas    | Notch / home indicator | None                                              |
| Auth          | Face ID (Phase 1)      | System/session                                    |
| Window        | Fixed phone sizes      | Resizable; content max-width ~960–1120px centered |

**Same:** theme tokens, components, routes, copy, currency formatting.

---

## 12. Theme Tokens (light / dark) — Tamagui

### Implementation sketch

```ts
// packages/ui/tamagui.config.ts
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
  },
  size: {
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
  },
  radius: {
    '0': 0,
    '1': 4,
    '2': 8,
    '3': 12,
    '4': 16,
    '6': 24,
  },
  zIndex: { '0': 0, '1': 100, '2': 200, '3': 300, '4': 400, '5': 500 },
});

const lightTheme = {
  background: tokens.color.background,
  color: tokens.color.onSurface,
  primary: tokens.color.primary,
  // ... map semantic tokens
};

const darkTheme = {
  background: '#121212',
  color: '#E6E1E5',
  primary: '#2DD4BF',
  // ... map semantic tokens (darker variants)
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
```

### Usage

```tsx
import { Stack, XStack, YStack, Text, Button, Card, Input, Theme } from '@expense/ui';

// Use shared components everywhere:
// - iPhone: <Button> renders to RN <Pressable>
// - Electron: <Button> renders to <button> (DOM)
// Both styled identically via Tamagui tokens.
```

### Runtime

- Wrap root in `<Theme name="light">` or `<Theme name="dark">`.
- Follow system: `useColorScheme()` from React Native; optional Settings override.
- **Never** read raw hex in feature screens — use tokens only.

---

## MVP build order (solo)

1. `packages/ui/tamagui.config.ts` + theme tokens + `Provider` wiring
2. Shared components: `Button`, `Card`, `Input`, `Chip`, `FAB`, `List.Item`
3. Transaction row + FAB + Add form
4. Dashboard metric cards + category chips
5. Tabs IA (Stack + Tabs)
6. Chart + a11y summary
7. Mac width tweak (side rail / max-width)

---

## Out of scope for this doc

Custom logo construction, marketing site, Phase 2 Electron chrome, family multi-user theming.

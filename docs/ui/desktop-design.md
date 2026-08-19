# Desktop UI Design Document

> UI design for Expense Tracker desktop app (mac-web / mac-electron), inspired by the Dribbble Finance Dashboard layout.

**Status:** Draft · **Version:** 1.0 · **Updated:** 2026-08-19

This document defines the design system and screen layouts for the desktop application. It adapts the Dribbble Finance Dashboard concept — a card-based grid with orange accents and light/dark themes — to Expense Tracker's brand and Catppuccin Frappé color scheme.

---

## 1. Design Principles

| Principle | Description |
|-----------|-------------|
| **Clarity first** | Every number, label, and chart should be instantly understandable. |
| **Data density without clutter** | Use a card-based grid (Bento box) to organize information. |
| **Consistent hierarchy** | Large bold metrics → medium labels → small gray descriptions. |
| **Vietnamese UI** | All user-facing text in Vietnamese. |
| **Accessible** | WCAG 2.1 AA contrast, keyboard navigation, screen reader support. |
| **Light & dark** | Full Catppuccin Frappé support for both themes. |

---

## 2. Color Palette

### Catppuccin Frappé — Light Mode (Default)

| Token | Hex | Usage |
|-------|-----|-------|
| `base` | `#303446` | Page background |
| `surface0` | `#414559` | Card background (elevated) |
| `surface1` | `#51576d` | Card background (default) |
| `surface2` | `#626880` | Card hover state |
| `overlay0` | `#737994` | Dividers, borders |
| `overlay1` | `#838ba7` | Placeholder text |
| `overlay2` | `#949cbb` | Secondary text |
| `subtext0` | `#a5adce` | Muted text |
| `subtext1` | `#c6d0f5` | Primary text on dark |
| `text` | `#c6d0f5` | Primary text (used on dark bg) |
| `lavender` | `#babbf1` | Accent (secondary) |
| `blue` | `#8caaee` | Information, links |
| `sapphire` | `#85c1dc` | Information (subtle) |
| `sky` | `#99d1db` | Information (light) |
| `teal` | `#81c8be` | Success (subtle) |
| `green` | `#a6d189` | Positive trends, income |
| `yellow` | `#e5c890` | Warnings, attention |
| `peach` | `#f2d5cf` | Neutral accent |
| `maroon` | `#ea999c` | Destructive (subtle) |
| `red` | `#e78284` | Negative trends, expenses |
| `mauve` | `#ca9ee6` | Purple accent |
| `pink` | `#f4b8e4` | Pink accent |
| `flamingo` | `#eebebe` | Neutral warm |
| `rosewater` | `#f2d5cf` | Highlight |

### Semantic Tokens (Light)

| Token | Value | Usage |
|-------|-------|-------|
| `--bg-base` | `#303446` | Page background |
| `--bg-card` | `#414559` | Card background |
| `--bg-card-hover` | `#51576d` | Card hover |
| `--bg-elevated` | `#51576d` | Elevated surfaces |
| `--border` | `#626880` | Borders, dividers |
| `--text-primary` | `#c6d0f5` | Headings, key metrics |
| `--text-secondary` | `#a5adce` | Labels, descriptions |
| `--text-muted` | `#737994` | Placeholders, hints |
| `--accent` | `#f4b8e4` | Primary accent (pink) |
| `--accent-hover` | `#eebebe` | Accent hover |
| `--income` | `#a6d189` | Income, positive |
| `--expense` | `#e78284` | Expenses, negative |
| `--transfer` | `#8caaee` | Transfers, neutral |
| `--warning` | `#e5c890` | Warnings |
| `--info` | `#85c1dc` | Information |

### Dark Mode

For dark mode, invert the surface hierarchy:

| Token | Value | Usage |
|-------|-------|-------|
| `--bg-base` | `#232634` | Darker base |
| `--bg-card` | `#292c3c` | Card background |
| `--bg-card-hover` | `#303446` | Card hover |
| `--bg-elevated` | `#414559` | Elevated surfaces |
| `--border` | `#51576d` | Borders |

---

## 3. Typography

### Font Family

```css
font-family: 'Inter', -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
```

### Type Scale

| Token | Size | Weight | Line-height | Usage |
|-------|------|--------|-------------|-------|
| `--font-xs` | 12px | 400 | 16px | Labels, badges |
| `--font-sm` | 14px | 400 | 20px | Secondary text |
| `--font-base` | 16px | 400 | 24px | Body text |
| `--font-lg` | 18px | 500 | 28px | Card titles |
| `--font-xl` | 20px | 600 | 28px | Section headers |
| `--font-2xl` | 24px | 700 | 32px | Page titles |
| `--font-3xl` | 32px | 800 | 40px | Key metrics (balance) |
| `--font-4xl` | 48px | 800 | 56px | Hero numbers |

### Number Formatting

```css
font-variant-numeric: tabular-nums;
font-feature-settings: 'tnum';
```

All financial figures use tabular numbers for alignment.

---

## 4. Spacing & Grid

### Spacing Scale

| Token | Value | Usage |
|-------|-------|-------|
| `--space-1` | 4px | Tight spacing |
| `--space-2` | 8px | Icon + text |
| `--space-3` | 12px | Within components |
| `--space-4` | 16px | Card padding (compact) |
| `--space-5` | 20px | Card padding (default) |
| `--space-6` | 24px | Card padding (generous) |
| `--space-8` | 32px | Section gaps |
| `--space-10` | 40px | Page margins |
| `--space-12` | 48px | Large section gaps |

### Grid System

```css
display: grid;
grid-template-columns: repeat(12, 1fr);
gap: 24px;
max-width: 1440px;
margin: 0 auto;
padding: 0 40px;
```

### Responsive Breakpoints

| Breakpoint | Width | Columns | Usage |
|------------|-------|---------|-------|
| `xs` | < 600px | 4 | Mobile (fallback) |
| `sm` | 600-899px | 8 | Tablet |
| `md` | 900-1199px | 12 | Small laptop |
| `lg` | 1200-1439px | 12 | Desktop |
| `xl` | ≥ 1440px | 12 | Large desktop |

---

## 5. Components

### 5.1 Card

```css
.card {
  background: var(--bg-card);
  border-radius: 16px;
  padding: 24px;
  box-shadow: 0 1px 3px rgba(0, 0, 0, 0.1);
  transition: box-shadow 0.2s ease;
}
.card:hover {
  box-shadow: 0 4px 12px rgba(0, 0, 0, 0.15);
}
```

**Variants:**
- `card--highlight` — Pink/orange accent background for featured cards
- `card--compact` — 16px padding
- `card--interactive` — Hover cursor pointer

### 5.2 Stat Card

Displays a single metric with trend indicator.

```tsx
<StatCard
  title="Tổng số dư"
  value="128.430.500"
  currency="VND"
  trend={{ value: 12.4, label: "so với tuần trước" }}
  icon={<WalletIcon />}
/>
```

**Layout:**
- Icon + title (top)
- Large bold value + currency
- Trend indicator (green ↑ / red ↓)

### 5.3 Chart Card

Container for charts with header and filter.

```tsx
<ChartCard
  title="Tổng quan thu nhập"
  filter={<Dropdown options={['Năm nay', 'Tháng này']} />}
  chart={<BarChart data={monthlyData} />}
/>
```

### 5.4 Button

| Variant | Style | Usage |
|---------|-------|-------|
| `primary` | Pink bg, white text | Main actions |
| `secondary` | Surface bg, text color | Secondary actions |
| `ghost` | Transparent, text color | Tertiary actions |
| `danger` | Red bg, white text | Destructive actions |

```css
.btn {
  padding: 10px 20px;
  border-radius: 10px;
  font-weight: 600;
  font-size: 14px;
  transition: all 0.15s ease;
}
.btn--sm { padding: 6px 12px; font-size: 12px; border-radius: 8px; }
.btn--lg { padding: 14px 28px; font-size: 16px; border-radius: 12px; }
```

### 5.5 Navigation Pill

```css
.nav-pill {
  padding: 8px 16px;
  border-radius: 20px;
  font-weight: 500;
  font-size: 14px;
  color: var(--text-secondary);
}
.nav-pill--active {
  background: var(--accent);
  color: var(--bg-base);
}
```

### 5.6 Dropdown

```css
.dropdown {
  padding: 8px 12px;
  border-radius: 8px;
  border: 1px solid var(--border);
  background: var(--bg-card);
  font-size: 14px;
  color: var(--text-primary);
}
```

### 5.7 Progress Bar

```css
.progress {
  height: 8px;
  border-radius: 4px;
  background: var(--bg-elevated);
}
.progress__bar {
  height: 100%;
  border-radius: 4px;
  background: var(--accent);
  transition: width 0.3s ease;
}
```

### 5.8 Badge

```css
.badge {
  padding: 4px 10px;
  border-radius: 12px;
  font-size: 12px;
  font-weight: 600;
}
.badge--income { background: rgba(166, 209, 137, 0.2); color: var(--income); }
.badge--expense { background: rgba(231, 130, 132, 0.2); color: var(--expense); }
.badge--transfer { background: rgba(140, 170, 238, 0.2); color: var(--transfer); }
```

### 5.9 Input

```css
.input {
  padding: 10px 14px;
  border-radius: 10px;
  border: 1px solid var(--border);
  background: var(--bg-card);
  font-size: 14px;
  color: var(--text-primary);
  transition: border-color 0.15s ease;
}
.input:focus {
  border-color: var(--accent);
  outline: none;
  box-shadow: 0 0 0 3px rgba(244, 184, 228, 0.2);
}
```

### 5.10 Skeleton (Loading)

```css
.skeleton {
  background: linear-gradient(90deg, var(--bg-card) 25%, var(--bg-elevated) 50%, var(--bg-card) 75%);
  background-size: 200% 100%;
  animation: shimmer 1.5s infinite;
  border-radius: 8px;
}
@keyframes shimmer {
  0% { background-position: 200% 0; }
  100% { background-position: -200% 0; }
}
```

---

## 6. Screen Designs

### 6.1 Dashboard

```
┌─────────────────────────────────────────────────────────────────────┐
│  [Logo] Expense Tracker    [Dashboard][Thu nhập][Chi tiêu][Chuyển][Ví]    [🔔][EN][👤] │
├─────────────────────────────────────────────────────────────────────┤
│  Tổng quan tài chính                    [Tháng này ▼]              │
│  Theo dõi dòng tiền của bạn            [Tổng quan][Giao dịch][Ngân sách][Báo cáo] │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  ┌──────────────────────────────────┐  ┌────────────────────────┐  │
│  │  Tổng số dư                      │  │  Thu nhập              │  │
│  │  [💼]                            │  │  [💰]                  │  │
│  │                                  │  │                        │  │
│  │  128.430.500 VND                 │  │  12.540.000 VND        │  │
│  │  ↑ +12.4% so với tuần trước      │  │  ↑ +8.2% tháng trước   │  │
│  │                                  │  │                        │  │
│  │  [Nhận tiền] [Gửi tiền] [Yêu cầu]│  └────────────────────────┘  │
│  └──────────────────────────────────┘                               │
│                                          ┌────────────────────────┐  │
│  ┌──────────────────────────────────┐  │  Chi tiêu              │  │
│  │  Tổng quan thu nhập              │  │  [💸]                  │  │
│  │  [Năm nay ▼]                     │  │                        │  │
│  │                                  │  │  5.000.000 VND         │  │
│  │  98.643.240 VND                  │  │  ↓ -5.3% tháng trước   │  │
│  │  ↑ +12.4%                        │  │                        │  │
│  │                                  │  └────────────────────────┘  │
│  │  ┌────────────────────────────┐  │                               │
│  │  │  Jan Feb Mar Apr May Jun  │  │  ┌────────────────────────┐  │
│  │  │  ██  ██  ██  ██  ██  ██  │  │  │  Lợi nhuận            │  │
│  │  │  Jul                      │  │  │  [📊]                  │  │
│  │  │  ██ 76.3k                 │  │  │                        │  │
│  │  │  ██  ██  ██  ██  ██  ██  │  │  │  7.540.000 VND         │  │
│  │  └────────────────────────────┘  │  │  ↑ +12.2% tháng trước  │  │
│  │                                  │  │  [Donut chart]         │  │
│  └──────────────────────────────────┘  └────────────────────────┘  │
│                                                                     │
│  ┌──────────────────────────────────┐  ┌────────────────────────┐  │
│  │  Mục tiêu tiết kiệm              │  │  Báo cáo tài chính     │  │
│  │  [🔒]              [+ Thêm mục]  │  │  [📄] (accent card)    │  │
│  │                                  │  │                        │  │
│  │  Quỹ khẩn cấp                   │  │  Tổng quan thu nhập    │  │
│  │  [████████░░] 72%               │  │                        │  │
│  │  7.200.000 / 10.000.000 VND     │  │  Lương: 4.500.000      │  │
│  │                                  │  │  Freelance: 12.500.000 │  │
│  │  Du lịch Châu Âu                 │  │  Kinh doanh: 66.500.000│  │
│  │  [████░░░░░░] 28%               │  │                        │  │
│  │  1.400.000 / 5.000.000 VND     │  │                        │  │
│  │                                  │  │                        │  │
│  │  Tesla Model 3                   │  │                        │  │
│  │  [█████████░] 45%               │  │                        │  │
│  │  13.500.000 / 30.000.000 VND   │  │                        │  │
│  └──────────────────────────────────┘  └────────────────────────┘  │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

**Grid layout:**
- Total Balance: `col-span-8`
- Income / Expenses / Net Profit: `col-span-4` each (stacked)
- Earning Overview: `col-span-8`
- Savings Goals: `col-span-8`
- Financial Report: `col-span-4`

### 6.2 Transactions

```
┌─────────────────────────────────────────────────────────────────────┐
│  [Logo]    [Dashboard][Thu nhập][Chi tiêu][Chuyển][Ví]    [🔔][EN][👤] │
├─────────────────────────────────────────────────────────────────────┤
│  Giao dịch                                                          │
│  Tất cả giao dịch gần đây                                          │
│                                                                     │
│  [🔍 Tìm kiếm...]              [Tất cả ▼] [Tháng này ▼] [+ Thêm]   │
│                                                                     │
│  ┌─────────────────────────────────────────────────────────────────┐│
│  │  Hôm nay                                                        ││
│  │  ┌──────────────────────────────────────────────────────────┐  ││
│  │  │ [🍜] Ăn trưa                    -150.000 VND   12:30    │  ││
│  │  │ [🚕] Grab về nhà               -45.000 VND    18:00    │  ││
│  │  │ [💰] Lương tháng 8             +12.500.000 VND 09:00   │  ││
│  │  └──────────────────────────────────────────────────────────┘  ││
│  │                                                                 ││
│  │  Hôm qua                                                        ││
│  │  ┌──────────────────────────────────────────────────────────┐  ││
│  │  │ [☕] Cà phê sáng                -35.000 VND    08:00    │  ││
│  │  │ [🛒] Siêu thị                  -280.000 VND   19:30    │  ││
│  │  └──────────────────────────────────────────────────────────┘  ││
│  └─────────────────────────────────────────────────────────────────┘│
└─────────────────────────────────────────────────────────────────────┘
```

### 6.3 Wallets

```
┌─────────────────────────────────────────────────────────────────────┐
│  [Logo]    [Dashboard][Thu nhập][Chi tiêu][Chuyển][Ví]    [🔔][EN][👤] │
├─────────────────────────────────────────────────────────────────────┤
│  Ví của tôi                                        [+ Thêm ví]      │
│                                                                     │
│  ┌──────────────────┐  ┌──────────────────┐  ┌──────────────────┐  │
│  │  [💵] Tiền mặt   │  │  [🏦] Vietcombank │  │  [📱] MoMo       │  │
│  │                  │  │                  │  │                  │  │
│  │  5.240.000 VND   │  │  45.000.000 VND  │  │  2.300.000 VND   │  │
│  │                  │  │                  │  │                  │  │
│  │  [Chuyển] [Chi tiêu]│ │  [Chuyển] [Chi tiêu]│ │  [Chuyển] [Chi tiêu]│ │
│  └──────────────────┘  └──────────────────┘  └──────────────────┘  │
│                                                                     │
│  ┌──────────────────┐                                               │
│  │  [💳] Thẻ tín dụng│                                              │
│  │                  │                                               │
│  │  Nợ: 8.500.000   │                                               │
│  │  Hạn mức: 20.000.000                                             │
│  │  [████████░░] 42% │                                              │
│  └──────────────────┘                                               │
└─────────────────────────────────────────────────────────────────────┘
```

### 6.4 Budgets

```
┌─────────────────────────────────────────────────────────────────────┐
│  [Logo]    [Dashboard][Thu nhập][Chi tiêu][Chuyển][Ví]    [🔔][EN][👤] │
├─────────────────────────────────────────────────────────────────────┤
│  Ngân sách                                                          │
│  Theo dõi chi tiêu theo danh mục                   [+ Thêm ngân sách]│
│                                                                     │
│  ┌─────────────────────────────────────────────────────────────────┐│
│  │  Tổng ngân sách tháng 8                                         ││
│  │  [████████████████░░░░░░░░░░] 68%                               ││
│  │  Đã chi: 6.800.000 / 10.000.000 VND                             ││
│  └─────────────────────────────────────────────────────────────────┘│
│                                                                     │
│  ┌──────────────────────────────────┐  ┌────────────────────────┐  │
│  │  [🍜] Ăn uống                   │  │  [🚕] Di chuyển        │  │
│  │  [████████████░░░░] 75%         │  │  [██████████░░░░] 60%  │  │
│  │  3.000.000 / 4.000.000 VND      │  │  1.200.000 / 2.000.000 │  │
│  └──────────────────────────────────┘  └────────────────────────┘  │
│                                                                     │
│  ┌──────────────────────────────────┐  ┌────────────────────────┐  │
│  │  [🛒] Mua sắm                   │  │  [🎬] Giải trí         │  │
│  │  [██████████████████] 90% ⚠️    │  │  [██████░░░░░░░░] 40%  │  │
│  │  1.800.000 / 2.000.000 VND      │  │  400.000 / 1.000.000   │  │
│  └──────────────────────────────────┘  └────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────┘
```

### 6.5 Settings

```
┌─────────────────────────────────────────────────────────────────────┐
│  [Logo]    [Dashboard][Thu nhập][Chi tiêu][Chuyển][Ví]    [🔔][EN][👤] │
├─────────────────────────────────────────────────────────────────────┤
│  Cài đặt                                                            │
│                                                                     │
│  ┌─────────────────────────────────────────────────────────────────┐│
│  │  Giao diện                                                      ││
│  │                                                                 ││
│  │  Chủ đề                    [Sáng ●────── Tối]                   ││
│  │                                                                 ││
│  │  Ngôn ngữ                  [Tiếng Việt ▼]                       ││
│  │                                                                 ││
│  │  Tiền tệ mặc định          [VND ▼]                              ││
│  └─────────────────────────────────────────────────────────────────┘│
│                                                                     │
│  ┌─────────────────────────────────────────────────────────────────┐│
│  │  Dữ liệu                                                        ││
│  │                                                                 ││
│  │  Sao lưu                    [Tạo bản sao lưu]                  ││
│  │                                                                 ││
│  │  Khôi phục                  [Tải bản sao lưu]                  ││
│  │                                                                 ││
│  │  Xuất CSV                   [Xuất giao dịch]                   ││
│  └─────────────────────────────────────────────────────────────────┘│
│                                                                     │
│  ┌─────────────────────────────────────────────────────────────────┐│
│  │  Đồng bộ (Phase 2+)                                             ││
│  │                                                                 ││
│  │  iCloud                       [Bật ●────── Tắt]                 ││
│  │  Trạng thái                  Đã đồng bộ 2 phút trước           ││
│  └─────────────────────────────────────────────────────────────────┘│
└─────────────────────────────────────────────────────────────────────┘
```

---

## 7. Interaction States

### 7.1 Hover

```css
.card:hover {
  box-shadow: 0 4px 12px rgba(0, 0, 0, 0.15);
  transform: translateY(-1px);
}
```

### 7.2 Active / Pressed

```css
.btn:active {
  transform: scale(0.98);
}
.nav-pill--active {
  background: var(--accent);
  color: var(--bg-base);
}
```

### 7.3 Focus

```css
*:focus-visible {
  outline: 2px solid var(--accent);
  outline-offset: 2px;
}
```

### 7.4 Disabled

```css
.btn:disabled {
  opacity: 0.5;
  cursor: not-allowed;
}
```

### 7.5 Loading

```css
.skeleton {
  animation: shimmer 1.5s infinite;
}
```

### 7.6 Empty State

```
┌─────────────────────────────────────────────────────────────────────┐
│                                                                     │
│                           [📭]                                      │
│                                                                     │
│                     Chưa có giao dịch                               │
│                                                                     │
│              Thêm giao dịch đầu tiên để bắt đầu                     │
│                                                                     │
│                        [+ Thêm giao dịch]                           │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

### 7.7 Error State

```
┌─────────────────────────────────────────────────────────────────────┐
│                                                                     │
│                           [⚠️]                                      │
│                                                                     │
│                     Không thể tải dữ liệu                           │
│                                                                     │
│              Vui lòng thử lại hoặc kiểm tra kết nối                │
│                                                                     │
│                        [Thử lại]                                    │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

---

## 8. Component Inventory

### Core Components (packages/ui)

| Component | Description | Status |
|-----------|-------------|--------|
| `Card` | Base card container | Required |
| `StatCard` | Metric display with trend | Required |
| `ChartCard` | Chart container with header | Required |
| `Button` | Action button (4 variants) | Required |
| `IconButton` | Icon-only button | Required |
| `Input` | Text input field | Required |
| `Dropdown` | Select dropdown | Required |
| `Tabs` | Tab navigation | Required |
| `NavPill` | Navigation pill | Required |
| `Progress` | Progress bar | Required |
| `Badge` | Status badge | Required |
| `Avatar` | User avatar | Required |
| `Icon` | Icon wrapper | Required |
| `Skeleton` | Loading placeholder | Required |
| `EmptyState` | Empty state placeholder | Required |
| `ErrorState` | Error state placeholder | Required |
| `Modal` | Modal dialog | Required |
| `Toast` | Notification toast | Required |
| `Tooltip` | Hover tooltip | Required |
| `Table` | Data table | Required |
| `Pagination` | Table pagination | Required |
| `DatePicker` | Date selection | Required |
| `CurrencyInput` | Money input field | Required |
| `SearchInput` | Search with icon | Required |
| `Toggle` | Switch toggle | Required |
| `Checkbox` | Checkbox input | Required |
| `Radio` | Radio input | Required |

### Chart Components (packages/ui/charts)

| Component | Description | Status |
|-----------|-------------|--------|
| `BarChart` | Vertical bar chart | Required |
| `LineChart` | Line chart | Required |
| `DonutChart` | Donut/pie chart | Required |
| `Sparkline` | Inline sparkline | Required |
| `ProgressRing` | Circular progress | Required |

### Layout Components (packages/ui/layout)

| Component | Description | Status |
|-----------|-------------|--------|
| `AppShell` | Main app layout | Required |
| `TopBar` | Top navigation bar | Required |
| `Sidebar` | Side navigation | Required |
| `PageHeader` | Page title + actions | Required |
| `Grid` | CSS Grid wrapper | Required |
| `Stack` | Flex column | Required |
| `Row` | Flex row | Required |

---

## 9. File Structure

```
packages/ui/
├── src/
│   ├── components/
│   │   ├── Card.tsx
│   │   ├── StatCard.tsx
│   │   ├── ChartCard.tsx
│   │   ├── Button.tsx
│   │   ├── Input.tsx
│   │   ├── Dropdown.tsx
│   │   ├── Tabs.tsx
│   │   ├── NavPill.tsx
│   │   ├── Progress.tsx
│   │   ├── Badge.tsx
│   │   ├── Avatar.tsx
│   │   ├── Icon.tsx
│   │   ├── Skeleton.tsx
│   │   ├── EmptyState.tsx
│   │   ├── ErrorState.tsx
│   │   ├── Modal.tsx
│   │   ├── Toast.tsx
│   │   ├── Tooltip.tsx
│   │   ├── Table.tsx
│   │   ├── Pagination.tsx
│   │   ├── DatePicker.tsx
│   │   ├── CurrencyInput.tsx
│   │   ├── SearchInput.tsx
│   │   ├── Toggle.tsx
│   │   ├── Checkbox.tsx
│   │   └── Radio.tsx
│   ├── charts/
│   │   ├── BarChart.tsx
│   │   ├── LineChart.tsx
│   │   ├── DonutChart.tsx
│   │   ├── Sparkline.tsx
│   │   └── ProgressRing.tsx
│   ├── layout/
│   │   ├── AppShell.tsx
│   │   ├── TopBar.tsx
│   │   ├── Sidebar.tsx
│   │   ├── PageHeader.tsx
│   │   ├── Grid.tsx
│   │   ├── Stack.tsx
│   │   └── Row.tsx
│   ├── tokens/
│   │   ├── colors.ts
│   │   ├── typography.ts
│   │   ├── spacing.ts
│   │   └── shadows.ts
│   └── index.ts
├── package.json
└── tsconfig.json
```

---

## 10. Implementation Notes

### 10.1 Chart Library

Use **Recharts** for React-based charts:
- Responsive container support
- Customizable colors via props
- Good TypeScript support

### 10.2 Icons

Use **Lucide React** for consistent line icons:
- 1000+ icons
- Consistent 24x24 grid
- Stroke-based (customizable)

### 10.3 Theme Switching

```tsx
const [theme, setTheme] = useState<'light' | 'dark'>('light');

// Apply CSS variables
document.documentElement.setAttribute('data-theme', theme);
```

### 10.4 Currency Input

```tsx
<CurrencyInput
  currency="VND"
  value={amount}
  onChange={setAmount}
  placeholder="0"
/>
```

- Accepts digits only
- Formats with thousand separators on blur
- Sends raw minorUnits string to domain

### 10.5 Number Display

```tsx
<Amount value="128430500" currency="VND" />
// Renders: 128.430.500 ₫
```

Uses `Intl.NumberFormat('vi-VN')` with domain's `formatMoney()`.

---

## Appendix A: Design Tokens (JSON)

```json
{
  "color": {
    "light": {
      "bg-base": "#303446",
      "bg-card": "#414559",
      "bg-card-hover": "#51576d",
      "bg-elevated": "#51576d",
      "border": "#626880",
      "text-primary": "#c6d0f5",
      "text-secondary": "#a5adce",
      "text-muted": "#737994",
      "accent": "#f4b8e4",
      "accent-hover": "#eebebe",
      "income": "#a6d189",
      "expense": "#e78284",
      "transfer": "#8caaee",
      "warning": "#e5c890",
      "info": "#85c1dc"
    },
    "dark": {
      "bg-base": "#232634",
      "bg-card": "#292c3c",
      "bg-card-hover": "#303446",
      "bg-elevated": "#414559",
      "border": "#51576d",
      "text-primary": "#c6d0f5",
      "text-secondary": "#a5adce",
      "text-muted": "#737994",
      "accent": "#f4b8e4",
      "accent-hover": "#eebebe",
      "income": "#a6d189",
      "expense": "#e78284",
      "transfer": "#8caaee",
      "warning": "#e5c890",
      "info": "#85c1dc"
    }
  },
  "spacing": {
    "xs": "4px",
    "sm": "8px",
    "md": "16px",
    "lg": "24px",
    "xl": "32px",
    "2xl": "40px"
  },
  "radius": {
    "sm": "8px",
    "md": "10px",
    "lg": "12px",
    "xl": "16px",
    "full": "9999px"
  },
  "shadow": {
    "sm": "0 1px 2px rgba(0, 0, 0, 0.05)",
    "md": "0 4px 6px rgba(0, 0, 0, 0.1)",
    "lg": "0 10px 15px rgba(0, 0, 0, 0.1)"
  }
}
```

## Appendix B: References

| Document | Link |
|----------|------|
| Product Spec | [PRODUCT_SPEC.md](../../PRODUCT_SPEC.md) |
| Design Document | [DESIGN.md](../../DESIGN.md) |
| Dashboard Feature | [docs/features/03-dashboard.md](../../features/03-dashboard.md) |
| Architecture | [docs/system/02-architecture.md](../../system/02-architecture.md) |
| Dribbble Reference | [Finance Dashboard](https://dribbble.com/shots/27425883-Finance-Dashboard) |
| Catppuccin Frappé | [catppuccin.com](https://catppuccin.com) |

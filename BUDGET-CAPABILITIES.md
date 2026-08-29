# Capability Map: Budget and Goals

| Module id | Responsibility | Depends on |
|---|---|---|
| `budget-core` | Monthly six-jar plan, actual allocation, category mapping, and jar management | Existing transactions, recurring rules, savings, and investments |
| `goal-envelopes` | Accumulation targets such as a home, car, or trip | `budget-core` |
| `trip-workspace` | Two-phase trip saving and spending with category breakdown | `goal-envelopes` |
| `income-timeline` | Explain each recurring or one-off income allocation event | `budget-core` |
| `adaptive-coach` | Warn about overspend and suggest reallocation | `budget-core`, `goal-envelopes` |

Build order: `budget-core` → `goal-envelopes` → `trip-workspace`; add
`income-timeline` and `adaptive-coach` only after the core behaviour is trusted.


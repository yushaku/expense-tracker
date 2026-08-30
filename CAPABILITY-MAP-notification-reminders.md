# Capability Map: Notification Reminders

| Module id | Responsibility | Depends on |
|---|---|---|
| `notification-settings` | Persist reminder preferences, request notification authorization in context, and expose both reminder controls in Settings. | — |
| `daily-expense-reminder` | Schedule one private, repeating local reminder at the owner's chosen daily time. | `notification-settings` |
| `recurring-due-reminders` | Schedule private local reminders for active recurring rules on their due dates. | `notification-settings`, existing `RecurringRule` scheduling |

Build order: `notification-settings` → `daily-expense-reminder`, `recurring-due-reminders`.

The two reminder modules may be implemented independently after the shared settings and authorization boundary is stable.

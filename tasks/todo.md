# Notification Reminders

## Task 1: Preferences and deterministic plans

**Description:** Add the persisted preference contract, minute-of-day value, privacy-safe plan values, and pure daily/recurring plan generation.

**Acceptance criteria:**

- [x] Defaults are disabled, daily is 20:00, and recurring is 09:00.
- [x] Daily planning yields exactly one stable repeating request only when enabled and authorized.
- [x] Recurring planning respects pause, anchor, interval, month-end clamping, inclusive end date, configured fire time, deterministic identifiers, global ordering, and the nearest-60 ceiling.

**Verification:**

- [x] RED tests fail before production logic exists.
- [x] Focused macOS tests pass for `NotificationPreferencesTests`, `DailyExpenseReminderTests`, and `RecurringDueReminderTests`.

**Dependencies:** None.

**Files likely touched:**

- `MonMon/Notifications/NotificationPreferences.swift`
- `MonMon/Notifications/NotificationPlan.swift`
- `MonMonTests/Notifications/NotificationPreferencesTests.swift`
- `MonMonTests/Notifications/DailyExpenseReminderTests.swift`
- `MonMonTests/Notifications/RecurringDueReminderTests.swift`

**Estimated scope:** Medium, 5 files.

## Task 2: Authorization and request reconciliation

**Description:** Add a narrow notification-center client and a main-actor observable coordinator that requests permission in context, inspects pending requests, and reconciles only MonMon-owned identifiers.

**Acceptance criteria:**

- [x] Enabling from undetermined status requests only alert and sound authorization.
- [x] Denied/revoked status produces no plan and reports an actionable state to Settings.
- [x] Reconciliation adds current requests, removes stale MonMon requests, and preserves unrelated pending requests.

**Verification:**

- [x] RED coordinator tests fail before implementation.
- [x] `NotificationCoordinatorTests` pass with an in-memory client.
- [x] iOS compile succeeds under strict concurrency.

**Dependencies:** Task 1.

**Files likely touched:**

- `MonMon/Notifications/NotificationCenterClient.swift`
- `MonMon/Notifications/NotificationCoordinator.swift`
- `MonMonTests/Notifications/NotificationCoordinatorTests.swift`

**Estimated scope:** Medium, 3 files.

## Task 3: App lifecycle ownership

**Description:** Own and inject the coordinator from `MonMonApp`, refresh authorization and schedules without prompting on launch, and reconcile after active-scene recurring generation.

**Acceptance criteria:**

- [ ] The app owns one stable coordinator instance using `@State` with `@Observable`.
- [ ] Launch and every active transition refresh permission and reconcile both namespaces without prompting.
- [ ] Debug previews receive a self-contained coordinator dependency.

**Verification:**

- [ ] Existing app tests pass.
- [ ] iOS compile succeeds.
- [ ] Source inspection confirms no launch-time authorization request.

**Dependencies:** Task 2.

**Files likely touched:**

- `MonMon/App/MonMonApp.swift`
- `MonMon/App/ContentView.swift`
- `MonMon/Notifications/NotificationCoordinator.swift`

**Estimated scope:** Medium, 3 files.

## Task 4: Settings controls and localization

**Description:** Add a dedicated Notifications card with native toggles and time pickers, authorization feedback, a button to system Settings, and English/Vietnamese copy.

**Acceptance criteria:**

- [ ] Daily and recurring toggles are independent and each reveals its own time picker only while enabled.
- [ ] Enable/time/language changes reconcile requests; denial rolls back an ineffective toggle and explains how to grant access.
- [ ] Native controls have clear labels, identifiers, Dynamic Type behavior, and logical VoiceOver order.

**Verification:**

- [ ] Notification coordinator tests still pass.
- [ ] Settings preview and iOS target compile.
- [ ] String Catalog contains complete English and Vietnamese entries for the new UI and notification content.

**Dependencies:** Task 3.

**Files likely touched:**

- `MonMon/Settings/NotificationSettingsCard.swift`
- `MonMon/Settings/SettingsView.swift`
- `MonMon/Notifications/NotificationCoordinator.swift`
- `MonMon/Resources/Localizable.xcstrings`

**Estimated scope:** Medium, 4 files.

## Task 5: Recurring mutation refresh and final gates

**Description:** Reconcile recurring requests immediately after successful recurring-rule saves and deletions, then complete project-wide quality gates and review.

**Acceptance criteria:**

- [ ] Saving, pausing through edit, or deleting a rule rebuilds recurring requests only after persistence succeeds.
- [ ] Scheduling failure does not roll back a successfully persisted financial rule and is surfaced through coordinator state.
- [ ] No unrelated behavior or files change.

**Verification:**

- [ ] Focused notification tests pass.
- [ ] Full macOS test suite passes.
- [ ] Format lint and iOS compile pass.
- [ ] SwiftUI correctness and five-axis code review pass before commit.

**Dependencies:** Task 4.

**Files likely touched:**

- `MonMon/Recurring/RecurringEditorView.swift`
- `MonMon/Notifications/NotificationCoordinator.swift`

**Estimated scope:** Small, 2 files plus final verification.

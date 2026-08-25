# Tasks: Statement Share Intake

## Task 1: Define the staged-item contract and atomic inbox store

**Description:** Add a platform-independent store that validates one PDF,
derives an opaque content id, writes a fixed PDF and JSON manifest into a
partial directory, atomically publishes it, lists valid pending items, reads
bytes, and explicitly removes an item. Begin with failing tests.

**Acceptance criteria:**

- [x] Valid fake PDF bytes round-trip through one ready item.
- [x] Repeated or renamed identical bytes produce one stable pending item.
- [x] Invalid, oversized, partial, malformed, and path-like input cannot become
      a ready item or escape the injected root.

**Verification:**

- [x] Focused `StatementIntakeStoreTests` pass.
- [x] Existing parser tests remain green.

**Dependencies:** None

**Files likely touched:**

- `MonMon/Imports/StatementIntakeStore.swift`
- `MonMonTests/Imports/StatementIntakeStoreTests.swift`
- `MonMon.xcodeproj/project.pbxproj`

**Estimated scope:** Medium, 3 files

## Checkpoint: Store

- [x] Store tests cover validation, idempotency, ordering, corruption, and removal.
- [x] Core source imports no UIKit and does not resolve entitlements itself.
- [x] Full macOS tests pass.

## Task 2: Add App Group capabilities and an embedded extension target

**Description:** Register the shared identifier in both entitlements, add an
iOS-only Share Extension target, embed it in MonMon, and configure an
exact-one-PDF activation predicate plus application-extension-only build rules.

**Acceptance criteria:**

- [x] Both binaries declare the same App Group identifier.
- [x] The extension target supports iPhone only and is embedded in the app.
- [x] Activation is restricted to exactly one attachment conforming to PDF.

**Verification:**

- [x] Project target graph builds for the iOS SDK.
- [x] Built extension Info.plist contains the expected extension point and rule.

**Dependencies:** Task 1

**Files likely touched:**

- `MonMon/MonMon.entitlements`
- `MonMonShareExtension/MonMonShareExtension.entitlements`
- `MonMonShareExtension/Info.plist`
- `MonMon.xcodeproj/project.pbxproj`

**Estimated scope:** Medium, 4 files

## Task 3: Load one PDF provider and render safe progress/result states

**Description:** Add the extension controller that selects one PDF provider,
loads its temporary file representation, resolves the App Group URL, delegates
all writes to the core store, and shows concise success or safe error states.

**Acceptance criteria:**

- [x] Exactly one PDF provider is accepted; missing or multiple providers fail.
- [x] Success and failure both expose a predictable close action.
- [x] UI and diagnostics expose no path, statement content, or parser data.

**Verification:**

- [ ] Provider orchestration tests pass where supported by the host test target.
- [x] Extension compiles with application-extension-safe APIs.

**Dependencies:** Task 2

**Files likely touched:**

- `MonMonShareExtension/ShareViewController.swift`
- `MonMonShareExtension/ShareIntakeView.swift`
- `MonMon.xcodeproj/project.pbxproj`
- `MonMonTests/Imports/StatementShareRequestTests.swift`

**Estimated scope:** Medium, 4 files

## Checkpoint: Extension

- [ ] One-PDF provider path stages successfully in tests.
- [ ] Invalid provider paths complete with safe errors.
- [x] App and embedded extension build together.

## Task 4: Clear automated gates and validate the share flow on Yushaku

**Description:** Run repository gates, install the containing app and extension
on the physical phone, and hand the final Files/bank-app share interaction to
the owner. Do not copy the owner's PDF into the repository or test logs.

**Acceptance criteria:**

- [x] Full automated gates are green.
- [ ] Physical build, install, and launch succeed.
- [ ] Owner can choose MonMon for one PDF and sees a safe staging result.

**Verification:**

- [x] Full macOS tests pass.
- [x] Recursive Swift format lint passes.
- [x] Compile-only iOS SDK build passes.
- [ ] `scripts/run-iphone.sh Yushaku` succeeds.
- [ ] Repository contains no PDF, local statement path, or real statement data.

**Dependencies:** Task 3

**Files likely touched:**

- `SPEC-statement-share-intake.md` only if physical behavior changes the spec
- `tasks/plan.md`
- `tasks/todo.md`

**Estimated scope:** Small, 3 files

## Checkpoint: Complete

- [ ] Approved spec success criteria are met.
- [ ] Definition of Done is satisfied.
- [ ] Human review approves intake before `transaction-import-inbox` begins.

## Current blocker

- [ ] Sign in to an Apple Developer account in Xcode.
- [ ] Register and enable `group.com.sonlv.monmon.local.yushaku` for the app and
      Share Extension identifiers.
- [ ] Regenerate/download provisioning profiles for
      `com.sonlv.monmon.local.yushaku` and
      `com.sonlv.monmon.local.yushaku.ShareExtension`.
- [ ] Rerun `scripts/run-iphone.sh Yushaku`, then perform the owner-operated
      one-PDF share-sheet check.

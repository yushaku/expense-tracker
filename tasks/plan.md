# Implementation Plan: Statement Share Intake

## Overview

Implement only `statement-share-intake`: one PDF enters through the iOS share
sheet, is validated and atomically staged in an App Group container, and becomes
available to the containing app. Parsing UI, reconciliation, and persistence
remain later modules.

## Dependency Graph

```text
Typed staging store + temporary-directory tests
    |
    v
App Group entitlements + Share Extension target
    |
    v
NSItemProvider adapter + safe extension result UI
    |
    v
iOS build/signing + physical share-sheet validation
```

## Architecture Decisions

- Core staging code is compiled into both targets and accepts an injected root
  URL; only platform adapters resolve the App Group container.
- A SHA-256 content id makes repeated delivery idempotent without exposing PDF
  text or source metadata.
- Fixed filenames live under a hash-named directory. The original filename is
  display metadata only.
- Partial directories are invisible to readers; one final same-volume move
  publishes a complete PDF plus manifest.
- The extension loads `UTType.pdf`, stages locally, completes the host request,
  and never attempts to open the containing app.
- `transaction-import-inbox` owns parsing presentation and final deletion.

## Task List

### Phase 1: Staging foundation

- [x] Task 1: Define the staged-item contract and atomic inbox store

### Checkpoint: Store

- [x] Validation, idempotency, listing, corruption, and removal tests pass.
- [x] No entitlement or UIKit dependency exists in the core store.

### Phase 2: Share Extension

- [x] Task 2: Add App Group capabilities and an embedded extension target
- [x] Task 3: Load one PDF provider and render safe progress/result states

### Checkpoint: Extension

- [x] Exact-one-PDF activation rule is present.
- [x] App and extension compile with the shared staging implementation.
- [x] Every success and failure exposes an explicit completion/cancellation action.

### Phase 3: Completion gates

- [ ] Task 4: Clear automated gates and validate the share flow on `Yushaku`

### Checkpoint: Complete

- [ ] Approved spec success criteria are met.
- [x] Full tests, format lint, and iOS SDK build pass.
- [ ] Physical build, install, launch, and one-PDF share invocation succeed.
- [x] Invalid input leaves no ready item in automated store tests.
- [x] No real PDF, statement content, local path, or generated output exists in
      the repository.
- [ ] Human reviews the intake checkpoint before `transaction-import-inbox`.

## Risks and Mitigations

| Risk | Impact | Mitigation |
|---|---|---|
| App Group is not registered for the signing team | High | Use one documented identifier; fail clearly; register it once if automatic provisioning cannot. |
| Host removes its temporary provider file | High | Copy and publish into the App Group before completing the request. |
| App reads while extension writes | High | Readers inspect only atomically moved ready directories. |
| Same statement is shared repeatedly | Medium | Use a complete-file SHA-256 id and return the existing ready item. |
| Filename attempts path traversal | High | Store under fixed filenames; sanitize metadata to a bounded last path component. |
| Extension exceeds memory or execution budget | High | Check file size before loading, cap at 25 MB, avoid parsing and network work. |
| Extension code uses unavailable APIs | High | Keep target small, set application-extension-only, and build the embedded target for iOS. |

## Verification Strategy

- Start each store behavior with a failing Swift Testing test.
- Build the extension after target wiring before adding provider orchestration.
- Test provider success/failure with fake `NSItemProvider` representations where
  feasible; keep storage behavior in the independently tested core store.
- Run full macOS tests, recursive format lint, compile-only iOS SDK build, then
  `scripts/run-iphone.sh Yushaku`.
- The owner performs the final share-sheet interaction with a local PDF; the
  agent reports only build/install/launch status and the owner reports UI result.

## Open Questions

- Physical signing is paused: Xcode has no signed-in developer account, the
  current app profile lacks App Groups, and no extension profile exists. The
  owner must register/enable the App Group and both bundle identifiers, then
  rerun `scripts/run-iphone.sh Yushaku`.

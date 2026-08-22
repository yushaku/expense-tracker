# Implementation Plan: app-bootstrap

## Overview

Create the smallest reproducible MonMon application shell: a checked-in Xcode
multiplatform project, explicit Debug/Release configuration, one shared scheme,
one SwiftUI greeting screen, and one smoke-test target. Finish by building both
platforms and launching the same app on Mac and iPhone Simulator.

## Architecture Decisions

- Use one native multiplatform application target for iOS and macOS, following
  Apple's documented SwiftUI/Xcode model.
- Keep the project dependency-free and generator-free; the `.xcodeproj` is the
  checked-in source of truth.
- Put reviewed settings in `Base.xcconfig`, `Debug.xcconfig`, and
  `Release.xcconfig`; keep only structural target settings in `project.pbxproj`.
- Commit one shared `MonMon` scheme so Xcode and command-line verification use the
  same build and test graph.
- Keep the visible greeting behind a small `AppCopy` constant so the smoke test
  validates actual app content without introducing UI-test complexity.
- Build unsigned for automated Mac and Simulator verification. Signing remains a
  user-controlled Xcode setting for later physical-device testing.

## Dependency Graph

```text
Repository hygiene and build settings
  -> Xcode project and shared scheme
    -> SwiftUI app and greeting screen
      -> Smoke-test target
        -> Debug/Release builds
          -> Mac and iPhone Simulator runtime checks
```

These steps are sequential because later checks require a valid project graph.
Formatting and repository-hygiene checks can run alongside platform builds once
the project exists.

## Implementation Slices

### Slice 1: Reproducible project configuration

- Add repository ignore rules, Swift formatting rules, build configuration files,
  project structure, supported destinations, and the shared scheme.
- Verify `xcodebuild -list` and `-showdestinations` can discover the project.

### Slice 2: Runnable Hello screen

- Add the SwiftUI app entry point, stable greeting copy, and accessible centered
  view.
- Build Debug for native macOS and generic iOS Simulator.

### Slice 3: Tests and release readiness

- Add the smoke-test target and test the greeting contract.
- Run strict formatting, unit tests, Debug builds, and Release builds.
- Confirm no warning, build artifact, signing material, or user-specific Xcode
  file has entered the repository.

### Slice 4: Runtime proof and handoff

- Launch and visually verify the Mac app.
- Provide exact iPhone Simulator and physical-device run instructions for the
  owner-managed hands-on check.
- Add exact setup/build/test/run instructions to README and provide the owner with
  the commands needed to reproduce the checks.

## Checkpoints

### Checkpoint A: Project discovered

- `xcodebuild` lists the `MonMon` project, scheme, app target, and test target.
- Debug/Release configurations resolve through the checked-in `.xcconfig` files.
- Human review is not required here unless the project contract differs from the
  approved spec.

### Checkpoint B: Both platforms compile

- macOS Debug build passes without compiler warnings.
- Generic iOS Simulator Debug build passes without compiler warnings.
- Formatting lint passes.

### Checkpoint C: app-bootstrap complete

- Unit tests pass.
- macOS and iOS Simulator Debug and Release builds pass.
- “Hello, MonMon” is visually confirmed on Mac; the owner confirms the app can be
  run and takes ownership of device testing.
- Repository hygiene check passes.
- Owner receives the runnable project and tests it before `cash-balance` work.

## Verification Commands

```sh
xcodebuild -project MonMon.xcodeproj -list
xcodebuild -project MonMon.xcodeproj -scheme MonMon -showdestinations
swift format lint --strict --recursive MonMon MonMonTests
xcodebuild -project MonMon.xcodeproj -scheme MonMon -configuration Debug -destination 'platform=macOS' -derivedDataPath /tmp/MonMonDerivedData CODE_SIGNING_ALLOWED=NO build
xcodebuild -project MonMon.xcodeproj -scheme MonMon -configuration Debug -sdk iphonesimulator -derivedDataPath /tmp/MonMonDerivedData CODE_SIGNING_ALLOWED=NO ONLY_ACTIVE_ARCH=NO build
xcodebuild -project MonMon.xcodeproj -scheme MonMon -configuration Debug -destination 'platform=macOS' -derivedDataPath /tmp/MonMonDerivedData CODE_SIGNING_ALLOWED=NO test
xcodebuild -project MonMon.xcodeproj -scheme MonMon -configuration Release -destination 'platform=macOS' -derivedDataPath /tmp/MonMonDerivedData CODE_SIGNING_ALLOWED=NO build
xcodebuild -project MonMon.xcodeproj -scheme MonMon -configuration Release -sdk iphonesimulator -derivedDataPath /tmp/MonMonDerivedData CODE_SIGNING_ALLOWED=NO ONLY_ACTIVE_ARCH=NO build
```

Runtime commands will use the specific installed Simulator destination returned by
`-showdestinations`; the device name is not hard-coded in the project.

## Risks and Mitigations

| Risk | Impact | Mitigation |
|---|---|---|
| Hand-authored Xcode project graph contains a stale or missing reference | High | Make project discovery and both platform builds the first checkpoints |
| Build settings drift into opaque `project.pbxproj` entries | Medium | Keep shared settings in small reviewed `.xcconfig` files |
| Physical-device signing blocks basic verification | Medium | Verify unsigned Mac/Simulator builds now; configure the owner's team only when testing a physical iPhone |
| CoreSimulator runtime is unavailable in the environment | Low | Keep iOS SDK compilation as automated evidence and let the owner run the app on their chosen device |
| A platform-specific API accidentally enters shared code | Medium | Compile the same application target for both platforms after every source change |

## Scope Guard

This plan ends at the greeting screen. It does not add SwiftData, CloudKit,
financial models, navigation architecture, network access, or MCP behavior.

## Open Questions

None. Any unavailable Simulator runtime is an environment condition to resolve
during verification, not a product-design decision.

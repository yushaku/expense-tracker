# Task List: app-bootstrap

This checklist implements `SPEC-app-bootstrap.md` and `tasks/plan.md`. Complete
tasks in order. Record verification evidence beneath each task before checking it
off.

## Task 1: Add repository and build configuration

**Description:** Establish deterministic formatting, ignore rules, and explicit
Debug/Release settings before creating the Xcode project graph.

**Acceptance criteria:**

- [x] Build products, DerivedData, signing files, and Xcode user state are ignored.
- [x] Swift 6 language mode, strict concurrency, deployment targets, bundle ID,
  and warning settings are defined in reviewed `.xcconfig` files.
- [x] Debug and Release configuration differences are explicit and minimal.

**Verification:**

- [x] `swift format lint --strict --recursive MonMon MonMonTests` can read the
  checked-in formatting configuration once sources exist.
- [x] Manual review confirms no credential, signing identity, or absolute
  developer-machine path is present.

**Evidence:** `swift format dump-configuration --effective --configuration
.swift-format` parsed the configuration; `git check-ignore -v` matched
DerivedData, local xcconfig, Xcode user state, and signing fixtures; targeted
secret/path scan returned no configuration finding (2026-08-22).

**Dependencies:** None

**Files likely touched:**

- `.gitignore`
- `.swift-format`
- `Config/Base.xcconfig`
- `Config/Debug.xcconfig`
- `Config/Release.xcconfig`

**Estimated scope:** Medium (5 files)

## Task 2: Create the discoverable multiplatform project graph

**Description:** Add the Xcode project, one iOS/macOS application target, one unit
test target, Debug/Release configuration mappings, and the shared scheme. Source
references may point to the files created by later tasks.

**Acceptance criteria:**

- [x] The application target supports iOS and native macOS from one target.
- [x] The unit-test target depends on and hosts against the application target.
- [x] The shared `MonMon` scheme builds the app and runs the test target.

**Verification:**

- [x] `xcodebuild -project MonMon.xcodeproj -list` reports project, targets,
  configurations, and scheme.
- [x] `xcodebuild -project MonMon.xcodeproj -scheme MonMon -showdestinations`
  reports macOS and iOS Simulator destination families, or records a scoped
  CoreSimulator environment blocker.

**Evidence:** `xcodebuild -list` reported `MonMon`, `MonMonTests`, Debug, Release,
and the shared `MonMon` scheme. `-showdestinations` reported My Mac, Any Mac, Any
iOS Device, and Any iOS Simulator Device; individual Simulator runtimes remain
blocked by sandboxed CoreSimulator access. `plutil` validated the project and
`xmllint` validated the scheme (2026-08-22).

**Dependencies:** Task 1

**Files likely touched:**

- `MonMon.xcodeproj/project.pbxproj`
- `MonMon.xcodeproj/xcshareddata/xcschemes/MonMon.xcscheme`

**Estimated scope:** Small (2 files)

## Checkpoint A: Project discovered

- [x] Tasks 1–2 acceptance criteria pass.
- [x] `xcodebuild` discovers the shared scheme and both targets.
- [x] No implementation code or out-of-scope feature has been added.

## Task 2A: Add a neutral compile harness

**Description:** Add the files referenced by the project without implementing the
greeting contract. This isolates the next TDD failure to `AppCopy.greeting`
instead of unrelated missing-file or asset-catalog errors.

**Acceptance criteria:**

- [x] The app has a valid SwiftUI entry point and renders an empty shared view.
- [x] `AppCopy` exists but has no greeting member.
- [x] The resource catalog is structurally valid and does not require an app icon
  before design assets exist.

**Verification:**

- [x] macOS Debug build succeeds before the greeting test is added.
- [x] No visible financial feature or greeting behavior exists.

**Evidence:** Strict Swift formatting passed and the unsigned arm64 macOS Debug
build succeeded with an empty `ContentView`. The only emitted warnings came from
sandboxed CoreSimulator/Xcode filesystem services, not project source or compiler
diagnostics (2026-08-22).

**Dependencies:** Task 2

**Files likely touched:**

- `Config/Base.xcconfig`
- `MonMon/App/MonMonApp.swift`
- `MonMon/App/AppCopy.swift`
- `MonMon/App/ContentView.swift`
- `MonMon/Resources/Assets.xcassets/Contents.json`

**Estimated scope:** Medium (5 small files)

## Task 3: Write the failing greeting smoke test

**Description:** Define the first observable app contract before implementation:
the stable greeting is exactly “Hello, MonMon”.

**Acceptance criteria:**

- [x] A Swift Testing test imports the app module and asserts the greeting copy.
- [x] The test initially fails to compile or fails its assertion because the app
  contract has not been implemented yet.
- [x] The failure is recorded as TDD red-state evidence.

**Verification:**

- [x] Run the macOS test command from `SPEC-app-bootstrap.md` and confirm the
  failure is specifically caused by the missing greeting contract.

**Evidence:** The macOS test build reached `MonMonTests/AppSmokeTests.swift` and
failed with `Type 'AppCopy' has no member 'greeting'`; the app target itself built
successfully. This is the intended TDD red state (2026-08-22).

**Dependencies:** Task 2A

**Files likely touched:**

- `MonMonTests/AppSmokeTests.swift`

**Estimated scope:** Extra small (1 file)

## Task 4: Implement the Hello app shell

**Description:** Add the minimum SwiftUI source and resource catalog needed to
make the failing smoke test pass and render the accessible greeting on both
platforms.

**Acceptance criteria:**

- [x] `MonMonApp` uses the SwiftUI lifecycle and opens `ContentView`.
- [x] `ContentView` centers “Hello, MonMon” and exposes the
  `app-greeting` accessibility identifier.
- [x] The greeting smoke test passes without adding unrelated abstractions.

**Verification:**

- [x] macOS unit-test command passes.
- [x] macOS Debug build passes.
- [x] Generic iOS Simulator Debug build passes.

**Evidence:** After adding only `AppCopy.greeting` and the accessible centered
`Text`, the macOS smoke test passed via local `testmanagerd`; the unsigned macOS
Debug build exited 0; the `iphonesimulator26.5` Debug build produced a universal
arm64/x86_64 `MonMon.app` executable. Strict Swift formatting passed
(2026-08-22).

**Dependencies:** Task 3

**Files likely touched:**

- `MonMon/App/MonMonApp.swift`
- `MonMon/App/AppCopy.swift`
- `MonMon/App/ContentView.swift`
- `MonMon/Resources/Assets.xcassets/Contents.json`

**Estimated scope:** Medium (4 files)

## Checkpoint B: Hello compiles on both platforms

- [x] Task 3 red-state and Task 4 green-state evidence are recorded.
- [x] macOS and generic iOS Simulator Debug builds pass without compiler warnings.
- [x] Strict formatting lint passes.
- [x] Git status contains no DerivedData, build product, or Xcode user-state file.

## Task 5: Verify release configurations and repository hygiene

**Description:** Exercise every non-runtime quality gate and correct only bootstrap
configuration defects found by those checks.

**Acceptance criteria:**

- [x] Debug and Release build successfully for macOS and the iOS Simulator SDK.
- [x] Unit tests and strict formatting pass.
- [x] Build logs contain no project compiler warnings.

**Verification:**

- [x] Run every applicable command in the Verification Commands section of
  `tasks/plan.md`.
- [x] `git status --short` contains only intended source, project, configuration,
  documentation, spec, plan, and task files.

**Evidence:** macOS Debug/Release builds exited 0; iOS Simulator SDK Debug/Release
builds exited 0 and produced arm64/x86_64 app executables; the macOS Swift Testing
suite and strict formatter passed. Xcode emitted only host-environment diagnostics
about sandboxed CoreSimulator/FileSystem services and destination selection—no
project compiler warning. The runtime-specific destination command remains Task 6
because no Simulator runtime is installed (2026-08-22).

**Dependencies:** Task 4

**Files likely touched:**

- No planned source change; only files from Tasks 1–4 if verification exposes a
  defect.

**Estimated scope:** Extra small (verification-focused)

## Task 6: Run both apps and document the handoff

**Description:** Launch the Mac product, hand device testing to the owner, and
document how the owner can reproduce every check.

**Acceptance criteria:**

- [x] Native Mac app visibly displays “Hello, MonMon”.
- [x] The owner confirms the app has been run and takes ownership of further
  hands-on testing.
- [x] README documents prerequisites, Xcode opening, build, test, Mac run, iPhone
  Simulator run, and the later physical-iPhone signing step.

**Verification:**

- [x] Capture or inspect runtime evidence for the Mac destination.
- [x] Follow README commands from a clean invocation and confirm they match the
  checked-in scheme/configuration.
- [x] Owner confirms they have run the app and will perform future app testing.

**Evidence:** The native Mac process launched from the Debug product, exposed a
900×450 `MonMon` window, and a window-only screenshot visibly showed the centered
greeting. The owner then reported the app had been run and asked to own further
app testing. The attempted iOS runtime download was cancelled immediately; iOS
Debug/Release SDK compilation remains verified (2026-08-22).

**Dependencies:** Task 5

**Files likely touched:**

- `README.md`

**Estimated scope:** Extra small (1 file plus runtime verification)

## Checkpoint C: app-bootstrap complete

- [x] All tasks and their verification steps are checked off with evidence.
- [x] Every success criterion in `SPEC-app-bootstrap.md` is satisfied under the
  owner-managed runtime-test boundary.
- [x] No SwiftData, CloudKit, finance, networking, or MCP code exists.
- [x] The owner can open and run the project and has the handoff instructions.
- [x] Stop for owner feedback before planning `cash-balance`.

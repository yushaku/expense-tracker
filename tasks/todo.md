# Task List: app-bootstrap

This checklist implements `SPEC-app-bootstrap.md` and `tasks/plan.md`. Complete
tasks in order. Record verification evidence beneath each task before checking it
off.

## Task 1: Add repository and build configuration

**Description:** Establish deterministic formatting, ignore rules, and explicit
Debug/Release settings before creating the Xcode project graph.

**Acceptance criteria:**

- [ ] Build products, DerivedData, signing files, and Xcode user state are ignored.
- [ ] Swift 6 language mode, strict concurrency, deployment targets, bundle ID,
  and warning settings are defined in reviewed `.xcconfig` files.
- [ ] Debug and Release configuration differences are explicit and minimal.

**Verification:**

- [ ] `swift format lint --strict --recursive MonMon MonMonTests` can read the
  checked-in formatting configuration once sources exist.
- [ ] Manual review confirms no credential, signing identity, or absolute
  developer-machine path is present.

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

- [ ] The application target supports iOS and native macOS from one target.
- [ ] The unit-test target depends on and hosts against the application target.
- [ ] The shared `MonMon` scheme builds the app and runs the test target.

**Verification:**

- [ ] `xcodebuild -project MonMon.xcodeproj -list` reports project, targets,
  configurations, and scheme.
- [ ] `xcodebuild -project MonMon.xcodeproj -scheme MonMon -showdestinations`
  reports macOS and iOS Simulator destination families, or records a scoped
  CoreSimulator environment blocker.

**Dependencies:** Task 1

**Files likely touched:**

- `MonMon.xcodeproj/project.pbxproj`
- `MonMon.xcodeproj/xcshareddata/xcschemes/MonMon.xcscheme`

**Estimated scope:** Small (2 files)

## Checkpoint A: Project discovered

- [ ] Tasks 1–2 acceptance criteria pass.
- [ ] `xcodebuild` discovers the shared scheme and both targets.
- [ ] No implementation code or out-of-scope feature has been added.

## Task 3: Write the failing greeting smoke test

**Description:** Define the first observable app contract before implementation:
the stable greeting is exactly “Hello, MonMon”.

**Acceptance criteria:**

- [ ] A Swift Testing test imports the app module and asserts the greeting copy.
- [ ] The test initially fails to compile or fails its assertion because the app
  contract has not been implemented yet.
- [ ] The failure is recorded as TDD red-state evidence.

**Verification:**

- [ ] Run the macOS test command from `SPEC-app-bootstrap.md` and confirm the
  failure is specifically caused by the missing greeting contract.

**Dependencies:** Task 2

**Files likely touched:**

- `MonMonTests/AppSmokeTests.swift`

**Estimated scope:** Extra small (1 file)

## Task 4: Implement the Hello app shell

**Description:** Add the minimum SwiftUI source and resource catalog needed to
make the failing smoke test pass and render the accessible greeting on both
platforms.

**Acceptance criteria:**

- [ ] `MonMonApp` uses the SwiftUI lifecycle and opens `ContentView`.
- [ ] `ContentView` centers “Hello, MonMon” and exposes the
  `app-greeting` accessibility identifier.
- [ ] The greeting smoke test passes without adding unrelated abstractions.

**Verification:**

- [ ] macOS unit-test command passes.
- [ ] macOS Debug build passes.
- [ ] Generic iOS Simulator Debug build passes.

**Dependencies:** Task 3

**Files likely touched:**

- `MonMon/App/MonMonApp.swift`
- `MonMon/App/AppCopy.swift`
- `MonMon/App/ContentView.swift`
- `MonMon/Resources/Assets.xcassets/Contents.json`

**Estimated scope:** Medium (4 files)

## Checkpoint B: Hello compiles on both platforms

- [ ] Task 3 red-state and Task 4 green-state evidence are recorded.
- [ ] macOS and generic iOS Simulator Debug builds pass without warnings.
- [ ] Strict formatting lint passes.
- [ ] Git status contains no DerivedData, build product, or Xcode user-state file.

## Task 5: Verify release configurations and repository hygiene

**Description:** Exercise every non-runtime quality gate and correct only bootstrap
configuration defects found by those checks.

**Acceptance criteria:**

- [ ] Debug and Release build successfully for macOS and generic iOS Simulator.
- [ ] Unit tests and strict formatting pass.
- [ ] Build logs contain no compiler warnings.

**Verification:**

- [ ] Run every command in the Verification Commands section of
  `tasks/plan.md`.
- [ ] `git status --short` contains only intended source, project, configuration,
  documentation, spec, plan, and task files.

**Dependencies:** Task 4

**Files likely touched:**

- No planned source change; only files from Tasks 1–4 if verification exposes a
  defect.

**Estimated scope:** Extra small (verification-focused)

## Task 6: Run both apps and document the handoff

**Description:** Launch the actual products, visually prove the greeting on Mac
and iPhone Simulator, and document how the owner can reproduce every check.

**Acceptance criteria:**

- [ ] Native Mac app visibly displays “Hello, MonMon”.
- [ ] The same app target visibly displays “Hello, MonMon” on an installed iPhone
  Simulator.
- [ ] README documents prerequisites, Xcode opening, build, test, Mac run, iPhone
  Simulator run, and the later physical-iPhone signing step.

**Verification:**

- [ ] Capture or inspect runtime evidence for both destinations.
- [ ] Follow README commands from a clean invocation and confirm they match the
  checked-in scheme/configuration.
- [ ] Owner is invited to run the app before `cash-balance` begins.

**Dependencies:** Task 5

**Files likely touched:**

- `README.md`

**Estimated scope:** Extra small (1 file plus runtime verification)

## Checkpoint C: app-bootstrap complete

- [ ] All six tasks and their verification steps are checked off with evidence.
- [ ] Every success criterion in `SPEC-app-bootstrap.md` is satisfied.
- [ ] No SwiftData, CloudKit, finance, networking, or MCP code exists.
- [ ] The owner can open and run the project and has the handoff instructions.
- [ ] Stop for hands-on owner testing before planning `cash-balance`.

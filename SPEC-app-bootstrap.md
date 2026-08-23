# Spec: app-bootstrap

## Objective

Create a clean, reproducible Xcode project that builds and runs one native SwiftUI
app on both iPhone and Mac. The only visible behavior is a centered
“Hello, MonMon” screen. This proves the toolchain, project structure, shared target,
tests, build configurations, and run destinations before financial behavior is
added.

This module contains no persistence, iCloud, networking, financial models, or MCP
code.

### User flow

1. Open `MonMon.xcodeproj` in Xcode.
2. Select the shared `MonMon` scheme and My Mac, then run the app.
3. See a native window containing “Hello, MonMon”.
4. Select an installed iPhone Simulator and run the same scheme.
5. See the same message in the simulated iPhone app.

## Tech Stack

- Xcode 26.6 (build 17F113) with installed macOS 26.5 and iOS Simulator 26.5 SDKs.
- Swift 6.3.3 in Swift 6 language mode with strict concurrency checking.
- One Xcode multiplatform application target supporting iOS and native macOS.
- One unit-test target using Swift Testing.
- SwiftUI app lifecycle and shared views.
- Minimum deployment versions: iOS 18 and macOS 15.
- Bundle identifier: `com.sonlv.monmon` until the owner requests a change.
- No project generators.

The configuration follows Apple's current guidance for a single multiplatform
target, checked-in build configuration files, a scheme/run destination, and
Simulator testing:

- <https://developer.apple.com/documentation/Xcode/configuring-a-multiplatform-app-target>
- <https://developer.apple.com/documentation/xcode/adding-a-build-configuration-file-to-your-project>
- <https://developer.apple.com/documentation/Xcode/running-your-app-on-simulated-or-physical-devices>

## Commands

Run from the repository root. Build products and DerivedData go to `/tmp` so they
do not dirty the repository.

```sh
xcodebuild -project MonMon.xcodeproj -scheme MonMon -configuration Debug -destination 'platform=macOS' -derivedDataPath /tmp/MonMonDerivedData CODE_SIGNING_ALLOWED=NO build
xcodebuild -project MonMon.xcodeproj -scheme MonMon -configuration Debug -sdk iphonesimulator -derivedDataPath /tmp/MonMonDerivedData CODE_SIGNING_ALLOWED=NO ONLY_ACTIVE_ARCH=NO build
xcodebuild -project MonMon.xcodeproj -scheme MonMon -configuration Debug -destination 'platform=macOS' -derivedDataPath /tmp/MonMonDerivedData CODE_SIGNING_ALLOWED=NO test
xcodebuild -project MonMon.xcodeproj -scheme MonMon -showdestinations
swift format lint --strict --recursive MonMon MonMonTests
```

Building through the `iphonesimulator` SDK keeps compilation independent from an
installed runtime. An installed iPhone destination returned by `-showdestinations`
is still required for the runtime smoke test. Release builds are also compiled
once at the completion checkpoint.

## Project Structure

```text
.gitignore
.swift-format
README.md
Config/
  Base.xcconfig
  Debug.xcconfig
  Release.xcconfig
MonMon.xcodeproj/
  project.pbxproj
  xcshareddata/xcschemes/MonMon.xcscheme
MonMon/
  App/
    MonMonApp.swift
    ContentView.swift
  Resources/
    Assets.xcassets/
MonMonTests/
  AppSmokeTests.swift
```

The checked-in shared scheme makes command-line and Xcode builds use the same
targets. User-specific Xcode workspace state and DerivedData are ignored.

## Code Style

- Use standard Swift naming and four-space indentation enforced by the checked-in
  `.swift-format` configuration.
- Use one primary type per source file.
- Keep the app entry point limited to scene composition.
- Keep visible copy in one testable constant until localization is introduced.
- Do not add an architectural abstraction until a real feature needs it.

```swift
enum AppCopy {
    static let greeting = "Hello, MonMon"
}

struct ContentView: View {
    var body: some View {
        Text(AppCopy.greeting)
            .accessibilityIdentifier("app-greeting")
    }
}
```

## Testing Strategy

- Add a Swift Testing smoke test that verifies the stable greeting copy.
- Build Debug for native macOS and a generic iOS Simulator destination.
- Build Release for native macOS and a generic iOS Simulator destination at the
  completion checkpoint.
- Run unit tests on macOS.
- Launch the macOS app for agent-side visual verification. The owner performs
  hands-on iPhone Simulator or physical-device testing and reports the result.
- Record any Simulator-runtime or signing limitation separately from compilation
  failures.

## Boundaries

### Always do

- Keep a single application target shared by iOS and native macOS.
- Keep Debug/Release settings in reviewed `.xcconfig` files.
- Commit the shared scheme and ignore user-specific Xcode state.
- Use repository-clean build output paths.
- Verify both platforms before declaring the module complete.

### Ask first

- Change bundle identifier, deployment targets, supported platforms, or signing
  team.
- Add a dependency, project generator, CI workflow, or additional app target.
- Add persistence, entitlements, capabilities, or network access.

### Never do

- Commit signing identities, provisioning profiles, credentials, or secrets.
- Add financial feature code to this bootstrap module.
- Require an Apple Developer account merely to compile simulator and unsigned Mac
  builds.
- Commit DerivedData, build products, or Xcode user state.

## Success Criteria

- `MonMon.xcodeproj` opens without missing file or package errors.
- The shared `MonMon` scheme is discoverable by `xcodebuild`.
- Debug and Release builds succeed for native macOS and iOS Simulator with no
  compiler warnings.
- Unit tests and strict Swift formatting checks pass.
- The macOS app launches and visibly shows “Hello, MonMon”.
- The owner can launch the same target on an iPhone Simulator or physical iPhone
  and verify “Hello, MonMon”.
- The repository remains free of DerivedData, build output, signing material, and
  user-specific Xcode files.
- README contains exact open, build, test, and run instructions.

## Open Questions

None. The owner handles hands-on app testing; automated verification remains part
of the repository workflow.

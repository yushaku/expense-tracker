# MonMon Agent Workflow

## Physical iPhone validation

All agents and sub-agents working in this repository must follow this workflow.

- Do not use an iPhone Simulator for runtime or UI validation unless the user explicitly requests it.
- After a relevant app change, build, install, and launch MonMon on the physical iPhone named `Yushaku` with `scripts/run-iphone.sh Yushaku`.
- The iPhone must be connected, unlocked, and have Developer Mode enabled. If it is unavailable, locked, or busy preparing, report that blocker and wait; do not silently fall back to a Simulator.
- Report only whether build, install, and launch succeeded. The user performs and owns hands-on UI and acceptance testing on the physical device.
- Unit tests, format lint, and non-Simulator build checks remain quality gates before commit or merge unless the user explicitly waives them.

## Branching

- Never commit to `main` directly. Branch first, from up-to-date `main`.
- Name the branch for the kind of change: `feat/<topic>`, `fix/<topic>`,
  `docs/<topic>`, `refactor/<topic>`. Use kebab-case for `<topic>`.
- Commit to that branch, then stop and report. Reviewing and merging is the
  user's call.
- Merge into `main` only when the user asks for it in that turn. Passing quality
  gates is not permission to merge, and permission given for one branch does not
  carry to the next.
- Do not push to `origin` unless the user asks.

## Building the app

Two flavours, picked by build configuration. They share no data: separate bundle
identifiers, app groups, and CloudKit containers. See the build flavours section
of `README.md` for the identifiers.

- Dev is the `Debug` configuration. Build, install, and launch it with
  `scripts/run-iphone.sh Yushaku`, following the physical iPhone workflow above.
  This is the flavour to use for every ordinary change.
- Prod is the `Release` configuration, built only by `scripts/build-prod.sh`,
  which refuses to run unless `HEAD` is a clean `main` matching `origin/main`.
  Build it only when the user asks. Never bypass that guard by calling
  `xcodebuild archive` by hand to work around a dirty tree or an unmerged
  branch; report the blocker instead.
- Never install a prod build over the user's dev install, or the reverse,
  without saying which flavour is going onto the phone.
- The dev app icon is generated art. After changing `AppIcon`, regenerate the
  dev variant with `swift scripts/make-dev-appicon.swift` rather than editing
  `AppIconDev.appiconset` by hand.

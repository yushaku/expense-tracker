# MonMon Agent Workflow

## Physical iPhone validation

All agents and sub-agents working in this repository must follow this workflow.

- Do not use an iPhone Simulator for runtime or UI validation unless the user explicitly requests it.
- Run `scripts/run-iphone.sh Yushaku` only from `dev`, after a branch has been merged into it. A change sitting on its own branch is not put on the phone: the phone carries what `dev` says it carries.
- The iPhone must be connected, unlocked, and have Developer Mode enabled. If it is unavailable, locked, or busy preparing, report that blocker and wait; do not silently fall back to a Simulator.
- Report only whether build, install, and launch succeeded. The user performs and owns hands-on UI and acceptance testing on the physical device.
- Unit tests, format lint, and non-Simulator build checks remain quality gates before commit or merge unless the user explicitly waives them. Compiling a branch without installing it is how those checks run before a merge.

## Branching

Work flows one way: a branch, then `dev`, then `main`. `dev` is what the user
tests on the phone; `main` is what a prod build is cut from.

- Never commit to `dev` or `main` directly. Branch first, from up-to-date `dev`.
- Name the branch for the kind of change: `feat/<topic>`, `fix/<topic>`,
`docs/<topic>`, `refactor/<topic>`. Use kebab-case for `<topic>`.
- Commit to that branch, then stop and report. Reviewing and merging is the
user's call.
- Merge into `dev` only when the user asks for it in that turn. Passing quality
gates is not permission to merge, and permission given for one branch does not
carry to the next. Once merged, put the result on the phone with
`scripts/run-iphone.sh Yushaku` so the user can test it.
- Never merge into `main`. The user promotes `dev` to `main` themselves, when
what they tested is what they want a prod build cut from.
- Do not push to `origin` unless the user asks.

## Building the app

Two flavours, picked by build configuration. They share no data: separate bundle
identifiers, app groups, and CloudKit containers. See the build flavours section
of `README.md` for the identifiers.

- Dev is the `Debug` configuration. Build, install, and launch it with
`scripts/run-iphone.sh Yushaku` from the `dev` branch, following the physical
iPhone workflow above. This is the flavour to use for every ordinary change.
- Prod is the `Release` configuration, built only by `scripts/build-prod.sh`,
which refuses to run unless `HEAD` is a clean `main` matching `origin/main`.
Build it only when the user asks, and only from a `main` the user promoted.
Never bypass that guard by calling `xcodebuild archive` by hand to work around
a dirty tree or an unmerged branch; report the blocker instead.
- Never install a prod build over the user's dev install, or the reverse,
without saying which flavour is going onto the phone.
- The dev app icon is generated art. After changing `AppIcon`, regenerate the
dev variant with `swift scripts/make-dev-appicon.swift` rather than editing
`AppIconDev.appiconset` by hand.



## SwiftUI

The app's UI is SwiftUI. The `swiftui-expert-skill` in `.claude/skills/` carries
the reference material for it.

- Use `swiftui-expert-skill` whenever you write, review, or refactor SwiftUI
code in this repository. Its `references/latest-apis.md` is the check against
reaching for a deprecated API.
- Follow its correctness checklist before you call SwiftUI work done. Those are
bugs, not preferences.
- Adopt Liquid Glass only when the user asks for it, and gate iOS 26+ APIs with
`#available` and a fallback.

<!-- CODEGRAPH_START -->

## CodeGraph

In repositories indexed by CodeGraph (a `.codegraph/` directory exists at the repo root), reach for it BEFORE grep/find or reading files when you need to understand or locate code:

- **MCP tool** (when available): `codegraph_explore` answers most code questions in one call — the relevant symbols' verbatim source plus the call paths between them, including dynamic-dispatch hops grep can't follow. Name a file or symbol in the query to read its current line-numbered source. If it's listed but deferred, load it by name via tool search.
- **Shell** (always works): `codegraph explore "<symbol names or question>"` prints the same output.

If there is no `.codegraph/` directory, skip CodeGraph entirely — indexing is the user's decision.

<!-- CODEGRAPH_END -->


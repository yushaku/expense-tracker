# Implementation Plan: Full Backup and Restore

## Outcome

Implement the approved `full-backup-restore` specification as a versioned JSON
snapshot that covers every SwiftData model and the approved logical preferences.
Restore is an explicit, previewed, authoritative replacement by UUID. Before any
store mutation, MonMon writes one private recovery snapshot that can be restored
from Settings.

## Dependency Graph

```text
Portable document contract + canonical scalar encoding
    |
    v
Pure validation + checksum + restore preview
    |
    v
SwiftData snapshot export + preferences
    |
    v
Recovery snapshot + transactional replacement restore
    |
    v
Settings UI + file importer/exporter + app-lock gate
    |
    v
Review, full gates, owner-directed merge and iPhone validation
```

## Architecture Decisions

- Use ordinary UTF-8 JSON and `UTType.json`; do not add CSV, encryption, merge,
  or database-file copying.
- Represent UUIDs as lowercase strings, Decimal values as canonical base-10
  strings, dates as UTC ISO-8601 with fractional seconds, and enums as raw
  strings.
- Compute SHA-256 over a canonical, sorted-key encoding of `payload` only.
- Keep document decoding and validation free of SwiftData and SwiftUI.
- Use a dedicated `ModelContext` with autosave disabled. Restore updates rows by
  UUID, inserts missing rows, deletes rows absent from the snapshot, and saves
  once; failures roll back.
- Write the pre-restore snapshot atomically under Application Support. On iOS,
  add complete file protection. If this write fails, restore does not start.
- Restore preferences only after the financial save succeeds.
- Treat imported JSON as untrusted. Reject files over 100 MB, unknown format or
  version, invalid scalar/enum values, duplicate IDs, dangling required
  references, invalid provenance hashes, non-finite/negative-invalid values,
  and checksum mismatch before creating a context that writes.
- The checksum detects damage, not malicious authorship; UI copy must not imply
  authenticity or encryption.

## Increment Strategy

1. Fix the pre-existing macOS `ShortcutsLink` compile blocker separately.
2. Add the portable document contract and canonical codec with failing tests.
3. Add pure validator and preview tests.
4. Add full snapshot export and preference capture with in-memory-store tests.
5. Add recovery snapshot and authoritative restore with rollback tests.
6. Add accessible Settings UI, import/export presentation, warnings, and app-lock
   authentication.
7. Run security/quality review, simplify, and execute all non-Simulator gates.

Every increment is a reviewable commit. No merge, push, or physical-device run
occurs without a new explicit owner request.

## Security Threat Model

| Threat | Boundary | Mitigation |
|---|---|---|
| Oversized or deeply malformed JSON exhausts memory | Imported file | Check resource size before reading; hard cap at 100 MB; decode once |
| Corrupted/tampered snapshot silently changes data | Document | Canonical payload SHA-256 and strict validation before writes |
| Partial destructive restore loses current data | Persistence | Private recovery snapshot, dedicated context, one save, rollback |
| Plaintext backup leaks financial data | Exported file | Explicit warning, no sensitive logs, protected private recovery file |
| Invalid references leave unusable records | Payload graph | Validate IDs, duplicates, enums, provenance, and required references |
| Restore bypasses enabled app lock | Settings action | Reuse app-lock authentication before restore confirmation |

## Completion Gates

- Focused contract, validator, export, restore, and UI-state tests pass.
- Full macOS unit tests pass.
- Recursive Swift format lint passes.
- Compile-only iOS SDK build passes without a Simulator.
- Diff contains no real owner data, backup output, paths, hashes, or unrelated
  changes.
- Physical iPhone validation remains pending until the owner asks to merge the
  branch into `dev`.

## Official Sources

- Apple `ModelContext`: https://developer.apple.com/documentation/swiftdata/modelcontext
- Apple `fileImporter`: https://developer.apple.com/documentation/swiftui/view/fileimporter%28ispresented%3Aallowedcontenttypes%3Aoncompletion%3A%29
- Apple Application Support directory: https://developer.apple.com/documentation/foundation/url/applicationsupportdirectory
- Apple atomic/protected data writing: https://developer.apple.com/documentation/foundation/nsdata/writingoptions/completefileprotection


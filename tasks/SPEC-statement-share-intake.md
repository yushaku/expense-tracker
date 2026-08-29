# Spec: Statement Share Intake

Module id: `statement-share-intake`

## Objective

Let an owner export one text-based PDF statement from a bank or Files app,
choose MonMon in the iOS share sheet, and stage that file locally for later
parsing and review. The Share Extension confirms whether staging succeeded but
does not create financial records or attempt to launch the containing app.

This module is the boundary between external share-sheet input and MonMon's
existing `bank-statement-parser`. It makes the file durable across the short
extension lifecycle while keeping the raw statement on device.

### Assumptions

1. The first slice accepts exactly one PDF attachment and rejects all other types.
2. A staged PDF is at most 25 MB, matching the parser boundary.
3. The app and extension share files through the registered App Group
   `group.com.sonlv.monmon.local.yushaku`.
4. Sharing identical bytes repeatedly is idempotent: one content hash maps to
   one pending item.
5. The extension reports success or a safe error. It never logs file contents,
   account data, references, or transaction text.
6. Review, editing, duplicate-row detection, transfer matching, and SwiftData
   writes remain outside this module.

## Interface Contract

```swift
struct StagedBankStatement: Codable, Sendable, Equatable, Identifiable {
    let id: String
    let originalFilename: String
    let byteCount: Int
    let createdAt: Date
}

struct StatementIntakeStore: Sendable {
    func stagePDF(at sourceURL: URL, originalFilename: String) throws
        -> StagedBankStatement
    func pendingStatements() throws -> [StagedBankStatement]
    func data(for statement: StagedBankStatement) throws -> Data
    func remove(_ statement: StagedBankStatement) throws
}
```

Contract rules:

- `id` is the lowercase SHA-256 digest of the complete PDF bytes. It is opaque
  and stable across filename changes and repeated shares.
- `originalFilename` is reduced to a safe last path component, normalized, and
  length-limited for display only. It is never used as a storage path.
- Each ready item lives in a hash-named directory containing fixed filenames
  for the PDF and JSON manifest.
- A writer creates a private partial directory and moves it into the ready
  inbox only after both files are durable. Readers never inspect partial items.
- Re-staging existing bytes returns the existing ready item without replacing
  it or creating a second pending item.
- `pendingStatements()` returns validated manifests in creation order and
  ignores incomplete or malformed directories.
- Errors are a closed enum covering unavailable App Group, unsupported type,
  oversized file, unreadable input, malformed staged item, and file-system
  failure. User-facing messages do not embed source text or paths.
- `remove` is exposed for the later inbox module but is not called
  automatically by this module.

## Tech Stack

- Swift 6 and the existing iOS 18 deployment target.
- Foundation for JSON manifests, file metadata, and atomic moves.
- CryptoKit for content-derived identifiers.
- UniformTypeIdentifiers using `UTType.pdf`.
- UIKit for a lightweight Share Extension controller.
- No network access and no new package dependency.

Apple requires an App Group entitlement for an extension and containing app to
share a container. The container URL must come from
`FileManager.containerURL(forSecurityApplicationGroupIdentifier:)`, never from
a constructed path. An `NSItemProvider` file representation is temporary, so
the extension copies it before completing the request.

Sources:

- [App Groups entitlement](https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.security.application-groups)
- [Sharing data between an extension and its containing app](https://developer.apple.com/library/archive/documentation/General/Conceptual/ExtensibilityPG/ExtensionScenarios.html)
- [`FileManager.containerURL(forSecurityApplicationGroupIdentifier:)`](https://developer.apple.com/documentation/foundation/filemanager/containerurl%28forsecurityapplicationgroupidentifier%3A%29)
- [`NSItemProvider.loadFileRepresentation`](https://developer.apple.com/documentation/foundation/nsitemprovider/loadfilerepresentation%28for%3Aopeninplace%3Acompletionhandler%3A%29)
- [PDF-only extension activation rule](https://developer.apple.com/library/archive/documentation/General/Conceptual/ExtensibilityPG/ExtensionScenarios.html#//apple_ref/doc/uid/TP40014214-CH5-SW7)
- [App extension lifecycle](https://developer.apple.com/library/archive/documentation/General/Conceptual/ExtensibilityPG/ExtensionOverview.html)

## Commands

Run macOS unit tests:

```sh
rtk xcodebuild -project MonMon.xcodeproj -scheme MonMon -configuration Debug -destination 'platform=macOS,arch=arm64' -derivedDataPath /tmp/MonMonDerivedData CODE_SIGNING_ALLOWED=NO test
```

Check Swift formatting:

```sh
rtk swift format lint --strict --recursive MonMon MonMonTests MonMonShareExtension
```

Build the iOS containing app and embedded extension without a Simulator runtime:

```sh
rtk xcodebuild -project MonMon.xcodeproj -scheme MonMon -configuration Debug -sdk iphonesimulator -derivedDataPath /tmp/MonMonDerivedDataIOS CODE_SIGNING_ALLOWED=NO ONLY_ACTIVE_ARCH=NO build
```

Build, install, and launch on the physical phone:

```sh
rtk scripts/run-iphone.sh Yushaku
```

## Project Structure

```text
MonMon/Imports/StatementIntakeStore.swift
    Shared staging contract and file-system implementation; belongs to both the
    app and Share Extension targets.

MonMonShareExtension/ShareViewController.swift
    Loads exactly one PDF provider, stages it, and renders safe progress/result.

MonMonShareExtension/Info.plist
    Share extension point and exact-one-PDF activation predicate.

MonMonShareExtension/MonMonShareExtension.entitlements
    App Group access for the extension.

MonMonTests/Imports/StatementIntakeStoreTests.swift
    Temporary-directory tests for validation, idempotency, atomic visibility,
    manifest corruption, ordering, and removal.
```

## Code Style

Inject the shared-container root into the core store so unit tests never depend
on entitlements:

```swift
let store = StatementIntakeStore(rootURL: sharedContainerURL)
let staged = try store.stagePDF(at: temporaryURL, originalFilename: filename)
```

- Validate external type, byte size, and PDF signature at the intake boundary.
- Use fixed storage filenames and content hashes; never concatenate the source
  filename into a path.
- Keep the core store synchronous and deterministic. Bridge the asynchronous
  item-provider callback only in the extension controller.
- Return typed errors; do not branch on localized error strings.
- Never print or interpolate the source URL, manifest, PDF data, or parser
  result into diagnostics.

## Testing Strategy

Tests use Swift Testing and temporary directories with fake PDF bytes.

Required cases:

- A valid fake PDF stages a ready manifest and round-trips identical bytes.
- Re-sharing identical bytes returns the same id and creates one pending item.
- A renamed identical PDF remains the same pending item.
- Unsupported signatures, empty files, and files over 25 MB fail before a
  ready directory appears.
- Source filenames containing path separators or excessive length cannot
  escape the inbox and are safely normalized.
- Partial and malformed directories never appear as pending statements.
- Pending items have deterministic ordering and can be removed explicitly.
- Extension target builds with application-extension-safe APIs only.
- The physical share sheet shows MonMon for exactly one PDF and staging reports
  success without launching or writing a transaction.

## Boundaries

### Always do

- Store raw files only in the local App Group container.
- Validate type, size, signature, filenames, and manifests as untrusted input.
- Publish a ready item atomically and make repeated delivery idempotent.
- Complete or cancel the host request on every extension path.
- Build, install, launch, and manually invoke the extension on `Yushaku`.

### Ask first

- Change the App Group or bundle identifiers.
- Add CSV, multiple attachments, OCR, or encrypted-PDF support.
- Add a dependency, background upload, analytics, or crash payload containing
  intake metadata.
- Auto-delete a staged statement or impose a pending-item retention policy.

### Never do

- Upload, sync through CloudKit, log, or commit a raw statement.
- Use the original filename as a directory or storage filename.
- Parse or create `MoneyTransaction` records inside the extension.
- Force-open the containing app from the Share Extension.
- Mark a partial write as ready or silently replace different content.

## Success Criteria

- MonMon appears in the iOS share sheet only for exactly one PDF attachment.
- Sharing a supported PDF stages one durable, locally readable pending item and
  displays a success state.
- Sharing identical bytes again does not create another pending item.
- Invalid, oversized, or unreadable input displays a safe failure and leaves no
  ready item.
- The app-side store can list and read staged bytes for the parser without
  accessing the host app's temporary URL.
- No statement is uploaded, logged, added to SwiftData, or copied into Git.
- Full tests, format lint, iOS SDK build, and physical-device workflow pass.

## Out of Scope

- Parsing inside the extension.
- Automatically opening MonMon after share completion.
- Import Inbox review/edit/skip/commit UI.
- Duplicate transaction and internal-transfer reconciliation.
- SwiftData schema changes or financial record creation.
- CSV, multiple files, OCR, and non-PDF inputs.

## Open Questions

- The App Group must exist for the current Apple Developer team before physical
  signing can succeed. If automatic provisioning cannot register it, the owner
  must create `group.com.sonlv.monmon.local.yushaku` once in the Developer
  portal and enable it for both bundle identifiers.
